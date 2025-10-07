import pool from "../config/db.js";
import { hotelIdByBookingId, managerOwnsHotel } from "./_ownership.util.js";


/** Kiểm tra phòng còn trống cho khoảng ngày */
const isRoomAvailable = async (roomId, checkIn, checkOut) => {
  const [rows] = await pool.query(
    `SELECT 1 FROM bookings b
     WHERE b.room_id = ?
       AND b.status IN ('pending','confirmed','completed')
       AND (? < b.check_out AND ? > b.check_in)
     LIMIT 1`,
    [roomId, checkIn, checkOut]
  );
  return rows.length === 0;
};

/** Kiểm tra phòng có bị chồng lịch trong khoảng check_in..check_out với các booking đang active hay không */
const hasOverlap = async (roomId, checkIn, checkOut, excludeBookingId = null) => {
  const params = [roomId, checkIn, checkOut];
  let excludeSql = "";
  if (excludeBookingId) { excludeSql = "AND b.id <> ?"; params.push(excludeBookingId); }

  const [rows] = await pool.query(
    `SELECT 1
       FROM bookings b
      WHERE b.room_id = ?
        AND b.status IN ('pending','confirmed','completed')
        AND (? < b.check_out AND ? > b.check_in)
        ${excludeSql}
      LIMIT 1`,
    params
  );
  return rows.length > 0;
};

export const createBooking = async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const userId = req.user.id; // từ protect
    const { room_id, check_in, check_out } = req.body;
    if (!room_id || !check_in || !check_out)
      return res.status(400).json({ message: "room_id, check_in, check_out required" });

    // lấy giá phòng
    const [roomRows] = await conn.query(
      "SELECT id, price_per_night FROM rooms WHERE id = ? LIMIT 1",
      [room_id]
    );
    if (!roomRows.length) return res.status(404).json({ message: "Room not found" });

    // check phòng trống
    const available = await isRoomAvailable(room_id, check_in, check_out);
    if (!available) return res.status(409).json({ message: "Room is not available in that range" });

    // tính tổng tiền = số đêm * price_per_night
    const [nightsRes] = await conn.query("SELECT DATEDIFF(?, ?) AS nights", [check_out, check_in]);
    const nights = Math.max(1, nightsRes[0].nights); // ít nhất 1 đêm
    const total = (Number(roomRows[0].price_per_night) * nights).toFixed(2);

    await conn.beginTransaction();
    const [result] = await conn.query(
      `INSERT INTO bookings (user_id, room_id, check_in, check_out, total_price, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [userId, room_id, check_in, check_out, total]
    );

    await conn.commit();
    res.status(201).json({ id: result.insertId, total_price: total, status: "pending" });
  } catch (e) {
    await pool.query("ROLLBACK");
    next(e);
  } finally {
    conn.release();
  }
};

export const completeBooking = async (req, res, next) => {
  try {
    const id = Number(req.params.id);

    // ⬇️ ownership check for manager
    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByBookingId(id);
      if (!hotelId) return res.status(404).json({ message: "Booking not found" });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    const [r] = await pool.query(
      "UPDATE bookings SET status='completed' WHERE id=? AND status IN ('pending','confirmed')",
      [id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ message: "Booking not updatable or not found" });
    res.json({ message: "Booking marked as completed" });
  } catch (e) { next(e); }
};

/** Admin/Manager: cập nhật trạng thái booking (pending|confirmed|cancelled) khi chưa completed */
export const updateBookingStatus = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { status } = req.body;

    const allowed = new Set(["pending", "confirmed", "cancelled"]);
    if (!Number.isInteger(id)) {
      return res.status(400).json({ message: "booking id must be an integer" });
    }
    if (!allowed.has(status)) {
      return res.status(400).json({ message: "status must be one of pending|confirmed|cancelled" });
    }

    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByBookingId(id);
      if (!hotelId) return res.status(404).json({ message: "Booking not found" });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    // Lấy thông tin booking hiện tại
    const [rows] = await pool.query(
      `SELECT b.id, b.status, b.room_id, b.check_in, b.check_out
         FROM bookings b
        WHERE b.id = ? 
        LIMIT 1`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ message: "Booking not found" });

    const bk = rows[0];

    // Không cho sửa nếu đã completed/cancelled (trừ khi muốn "cancelled" -> đã cancelled thì idempotent)
    if (bk.status === "completed") {
      return res.status(409).json({ message: "Completed booking cannot be changed" });
    }
    if (bk.status === "cancelled" && status !== "cancelled") {
      return res.status(409).json({ message: "Cancelled booking cannot be re-activated" });
    }

    // Khi xác nhận (confirmed), phải chắc không chồng lịch
    if (status === "confirmed") {
      const overlap = await hasOverlap(bk.room_id, bk.check_in, bk.check_out, bk.id);
      if (overlap) {
        return res.status(409).json({ message: "Cannot confirm: room is not available in that range" });
      }
    }

    // Cập nhật trạng thái
    const [r] = await pool.query(
      "UPDATE bookings SET status = ? WHERE id = ?",
      [status, id]
    );
    if (r.affectedRows === 0) {
      return res.status(500).json({ message: "Update failed" });
    }

    res.json({ message: "Booking status updated", id, status });
  } catch (e) { next(e); }
};