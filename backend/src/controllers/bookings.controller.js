import pool from "../config/db.js";
import { hotelIdByBookingId, managerOwnsHotel } from "./_ownership.util.js";
import { recordAudit } from "../utils/audit.js";

const ACTIVE_STATUSES = new Set(["pending", "confirmed", "completed"]);

const isRoomAvailable = async (roomId, checkIn, checkOut) => {
  const [rows] = await pool.query(
    `SELECT 1
       FROM bookings b
      WHERE b.room_id = ?
        AND b.status IN ('pending','confirmed','completed')
        AND (? < b.check_out AND ? > b.check_in)
      LIMIT 1`,
    [roomId, checkIn, checkOut],
  );
  return rows.length === 0;
};

const hasOverlap = async (roomId, checkIn, checkOut, excludeBookingId = null) => {
  const params = [roomId, checkIn, checkOut];
  let excludeSql = "";
  if (excludeBookingId) {
    excludeSql = "AND b.id <> ?";
    params.push(excludeBookingId);
  }

  const [rows] = await pool.query(
    `SELECT 1
       FROM bookings b
      WHERE b.room_id = ?
        AND b.status IN ('pending','confirmed','completed')
        AND (? < b.check_out AND ? > b.check_in)
        ${excludeSql}
      LIMIT 1`,
    params,
  );
  return rows.length > 0;
};

export const getBookingSummary = async (req, res, next) => {
  try {
    const role = req.user?.role ?? "customer";
    if (!["admin", "hotel_manager"].includes(role)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    let join = "";
    let where = "1=1";
    const params = [];

    if (role === "hotel_manager") {
      join =
        " JOIN rooms r ON r.id = b.room_id JOIN hotel_managers hm ON hm.hotel_id = r.hotel_id";
      where = "hm.user_id = ?";
      params.push(req.user.id);
    }

    let row = {};
    try {
      const [[qrow]] = await pool.query(
        `SELECT
            COUNT(*) AS total,
            SUM(b.status = 'pending') AS pending,
            SUM(b.status = 'confirmed') AS confirmed,
            SUM(b.status = 'completed') AS completed,
            SUM(b.status = 'cancelled') AS cancelled,
            COALESCE(SUM(CASE WHEN b.status IN ('pending','confirmed','completed') THEN b.total_price END), 0) AS valuePipeline,
            COALESCE(SUM(CASE WHEN b.status = 'completed' THEN b.total_price END), 0) AS valueCompleted
          FROM bookings b
          ${join}
          WHERE ${where}`,
        params,
      );
      row = qrow ?? {};
    } catch (sqlErr) {
      // If the hotel_managers table doesn't exist (dev / incomplete DB), return default zeros
      const msg = String(sqlErr?.message ?? sqlErr);
      if (msg.includes("doesn't exist") || msg.includes('ER_NO_SUCH_TABLE')) {
        row = {
          total: 0,
          pending: 0,
          confirmed: 0,
          completed: 0,
          cancelled: 0,
          valuePipeline: 0,
          valueCompleted: 0,
        };
      } else {
        throw sqlErr; // rethrow other SQL errors
      }
    }

    res.json({
      role,
      summary: {
        total: Number(row?.total ?? 0),
        pending: Number(row?.pending ?? 0),
        confirmed: Number(row?.confirmed ?? 0),
        completed: Number(row?.completed ?? 0),
        cancelled: Number(row?.cancelled ?? 0),
        valuePipeline: Number(row?.valuePipeline ?? 0),
        valueCompleted: Number(row?.valueCompleted ?? 0),
      },
    });
  } catch (err) {
    next(err);
  }
};

export const listBookings = async (req, res, next) => {
  try {
    const role = req.user?.role ?? "customer";
    const authUserId = req.user?.id;
    const queryUserIdRaw = req.query.userId ?? req.query.user_id;
    const queryUserId = Number(queryUserIdRaw);

    let targetUserId = null;
    if (role === "customer") {
      targetUserId = authUserId;
    } else if (Number.isInteger(queryUserId) && queryUserId > 0) {
      targetUserId = queryUserId;
    }

    let sql =
      `SELECT b.id,
              b.user_id,
              b.room_id,
              b.check_in,
              b.check_out,
              b.total_price,
              b.status,
              b.created_at,
              r.room_number,
              r.type AS room_type,
              r.price_per_night,
              h.name AS hotel_name
         FROM bookings b
         LEFT JOIN rooms r ON r.id = b.room_id
         LEFT JOIN hotels h ON h.id = r.hotel_id`;

    // Restrict partners to bookings of hotels they manage
    let extraJoin = "";
    const whereParts = [];
    const params = [];

    if (role === "hotel_manager") {
      extraJoin = " JOIN hotel_managers hm ON hm.hotel_id = r.hotel_id";
      whereParts.push("hm.user_id = ?");
      params.push(authUserId);
    }

    if (targetUserId) {
      whereParts.push("b.user_id = ?");
      params.push(targetUserId);
    }

    sql += extraJoin;
    if (whereParts.length) {
      sql += " WHERE " + whereParts.join(" AND ");
    }

    sql += " ORDER BY b.check_in DESC, b.created_at DESC, b.id DESC";

    const [rows] = await pool.query(sql, params);
    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};

export const createBooking = async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const userId = req.user.id;
    const { room_id, check_in, check_out } = req.body;
    if (!room_id || !check_in || !check_out) {
      return res.status(400).json({ message: "room_id, check_in, check_out required" });
    }

    const [roomRows] = await conn.query(
      `SELECT r.id,
              r.room_number,
              r.type,
              r.price_per_night,
              r.hotel_id,
              h.name AS hotel_name
         FROM rooms r
         JOIN hotels h ON h.id = r.hotel_id
        WHERE r.id = ?
        LIMIT 1`,
      [room_id],
    );
    if (!roomRows.length) {
      return res.status(404).json({ message: "Room not found" });
    }

    const available = await isRoomAvailable(room_id, check_in, check_out);
    if (!available) {
      return res.status(409).json({ message: "Room is not available in that range" });
    }

    const [nightsRows] = await conn.query(
      "SELECT DATEDIFF(?, ?) AS nights",
      [check_out, check_in],
    );
    const rawNights = Number(nightsRows[0]?.nights ?? 0);
    const nights = Math.max(1, rawNights);
    const roomRow = roomRows[0];
    const pricePerNight = Number(roomRow.price_per_night);
    const total = pricePerNight * nights;

    await conn.beginTransaction();
    const [result] = await conn.query(
      `INSERT INTO bookings (user_id, room_id, check_in, check_out, total_price, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [userId, room_id, check_in, check_out, total],
    );
    await conn.commit();

    res.status(201).json({
      data: {
        id: result.insertId,
        user_id: userId,
        room_id,
        check_in,
        check_out,
        total_price: total,
        nights,
        status: "pending",
        room_number: roomRow.room_number,
        room_type: roomRow.type,
        price_per_night: pricePerNight,
        hotel_name: roomRow.hotel_name,
      },
    });
  } catch (err) {
    await conn.rollback();
    next(err);
  } finally {
    conn.release();
  }
};

export const cancelBooking = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const role = req.user?.role ?? "customer";
    const userId = req.user?.id;

    if (!Number.isInteger(id)) {
      return res.status(400).json({ message: "booking id must be an integer" });
    }

    const [rows] = await pool.query(
      `SELECT id, user_id, status
         FROM bookings
        WHERE id = ?
        LIMIT 1`,
      [id],
    );
    if (!rows.length) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    if (role === "customer" && booking.user_id !== userId) {
      return res.status(403).json({ message: "You are not allowed to cancel this booking" });
    }

    if (!["pending", "confirmed"].includes(String(booking.status ?? "").toLowerCase())) {
      return res.status(409).json({ message: "Booking cannot be cancelled at this stage" });
    }

    const [result] = await pool.query(
      "UPDATE bookings SET status = 'cancelled' WHERE id = ?",
      [id],
    );
    if (result.affectedRows === 0) {
      return res.status(500).json({ message: "Cancel booking failed" });
    }

    await recordAudit({
      userId: req.user?.id,
      action: "booking.cancel",
      targetType: "booking",
      targetId: id,
      metadata: { previousStatus: booking.status },
    });

    res.json({ message: "Booking cancelled", id });
  } catch (err) {
    next(err);
  }
};

export const completeBooking = async (req, res, next) => {
  try {
    const id = Number(req.params.id);

    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByBookingId(id);
      if (!hotelId) {
        return res.status(404).json({ message: "Booking not found" });
      }
      const ownsHotel = await managerOwnsHotel(req.user.id, hotelId);
      if (!ownsHotel) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    const [details] = await pool.query(
      "SELECT status FROM bookings WHERE id = ? LIMIT 1",
      [id],
    );
    if (!details.length) {
      return res.status(404).json({ message: "Booking not found" });
    }
    const previousStatus = details[0].status;

    const [result] = await pool.query(
      "UPDATE bookings SET status = 'completed' WHERE id = ? AND status IN ('pending','confirmed')",
      [id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Booking not updatable or not found" });
    }
    await recordAudit({
      userId: req.user?.id,
      action: "booking.complete",
      targetType: "booking",
      targetId: id,
      metadata: { previousStatus },
    });
    res.json({ message: "Booking marked as completed" });
  } catch (err) {
    next(err);
  }
};

export const updateBookingStatus = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { status } = req.body;

    if (!Number.isInteger(id)) {
      return res.status(400).json({ message: "booking id must be an integer" });
    }
    if (!ACTIVE_STATUSES.has(status) && status !== "cancelled") {
      return res.status(400).json({ message: "status must be pending, confirmed or cancelled" });
    }

    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByBookingId(id);
      if (!hotelId) {
        return res.status(404).json({ message: "Booking not found" });
      }
      const ownsHotel = await managerOwnsHotel(req.user.id, hotelId);
      if (!ownsHotel) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    const [rows] = await pool.query(
      `SELECT b.id, b.status, b.room_id, b.check_in, b.check_out
         FROM bookings b
        WHERE b.id = ?
        LIMIT 1`,
      [id],
    );
    if (!rows.length) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    if (booking.status === "completed" && status !== "cancelled") {
      return res.status(409).json({ message: "Completed booking cannot be changed except cancellation" });
    }
    if (booking.status === "cancelled" && status !== "cancelled") {
      return res.status(409).json({ message: "Cancelled booking cannot be re-activated" });
    }

    if (status === "confirmed") {
      const overlap = await hasOverlap(booking.room_id, booking.check_in, booking.check_out, booking.id);
      if (overlap) {
        return res.status(409).json({ message: "Cannot confirm: room is not available in that range" });
      }
    }

    const [updateResult] = await pool.query(
      "UPDATE bookings SET status = ? WHERE id = ?",
      [status, id],
    );
    if (updateResult.affectedRows === 0) {
      return res.status(500).json({ message: "Update failed" });
    }

    await recordAudit({
      userId: req.user?.id,
      action: "booking.status.update",
      targetType: "booking",
      targetId: id,
      metadata: { previousStatus: booking.status, newStatus: status },
    });

    res.json({ message: "Booking status updated", id, status });
  } catch (err) {
    next(err);
  }
};

export const exportBookingSummary = async (req, res, next) => {
  try {
    const role = req.user?.role ?? "customer";
    if (!["admin", "hotel_manager"].includes(role)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    const { from, to, format = "xlsx" } = req.query;

    let join = "";
    let where = "1=1";
    const params = [];

    if (role === "hotel_manager") {
      join =
        " JOIN rooms r ON r.id = b.room_id JOIN hotel_managers hm ON hm.hotel_id = r.hotel_id";
      where = "hm.user_id = ?";
      params.push(req.user.id);
    }

    if (from) {
      where += " AND DATE(b.check_out) >= ?";
      params.push(from);
    }
    if (to) {
      where += " AND DATE(b.check_out) < DATE_ADD(?, INTERVAL 1 DAY)";
      params.push(to);
    }

    let row = {};
    try {
      const [[qrow]] = await pool.query(
        `SELECT
            COUNT(*) AS total,
            SUM(b.status = 'pending') AS pending,
            SUM(b.status = 'confirmed') AS confirmed,
            SUM(b.status = 'completed') AS completed,
            SUM(b.status = 'cancelled') AS cancelled,
            COALESCE(SUM(CASE WHEN b.status IN ('pending','confirmed','completed') THEN b.total_price END), 0) AS valuePipeline,
            COALESCE(SUM(CASE WHEN b.status = 'completed' THEN b.total_price END), 0) AS valueCompleted
          FROM bookings b
          ${join}
          WHERE ${where}`,
        params,
      );
      row = qrow ?? {};
    } catch (sqlErr) {
      const msg = String(sqlErr?.message ?? sqlErr);
      if (msg.includes("doesn't exist") || msg.includes('ER_NO_SUCH_TABLE')) {
        row = {
          total: 0,
          pending: 0,
          confirmed: 0,
          completed: 0,
          cancelled: 0,
          valuePipeline: 0,
          valueCompleted: 0,
        };
      } else {
        throw sqlErr;
      }
    }

    const fmt = String(format || "xlsx").toLowerCase();
    const fnameSuffix = [from ? String(from) : null, to ? String(to) : null].filter(Boolean).join("_");

    if (fmt === "csv") {
      const headers = [
        "From",
        "To",
        "Total",
        "Pending",
        "Confirmed",
        "Completed",
        "Cancelled",
        "ValuePipeline",
        "ValueCompleted",
      ];
      const values = [
        from || "",
        to || "",
        Number(row.total || 0),
        Number(row.pending || 0),
        Number(row.confirmed || 0),
        Number(row.completed || 0),
        Number(row.cancelled || 0),
        Number(row.valuePipeline || 0),
        Number(row.valueCompleted || 0),
      ];
      const csv = `${headers.join(',')}\n${values.join(',')}`;
      res.setHeader("Content-Type", "text/csv");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="booking_summary${fnameSuffix ? '_' + fnameSuffix : ''}.csv"`
      );
      return res.status(200).send(csv);
    }

    // Default: Excel
    const ExcelJS = (await import("exceljs")).default;
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet("Tổng quan");

    ws.columns = [
      { header: "Từ ngày", key: "from", width: 12 },
      { header: "Đến ngày", key: "to", width: 12 },
      { header: "Tổng đơn", key: "total", width: 10 },
      { header: "Chờ xác nhận", key: "pending", width: 12 },
      { header: "Đã xác nhận", key: "confirmed", width: 12 },
      { header: "Hoàn tất", key: "completed", width: 10 },
      { header: "Hủy", key: "cancelled", width: 8 },
      { header: "Giá trị pipeline", key: "valuePipeline", width: 16 },
      { header: "Giá trị hoàn tất", key: "valueCompleted", width: 16 },
    ];

    ws.addRow({
      from: from || "",
      to: to || "",
      total: Number(row.total || 0),
      pending: Number(row.pending || 0),
      confirmed: Number(row.confirmed || 0),
      completed: Number(row.completed || 0),
      cancelled: Number(row.cancelled || 0),
      valuePipeline: Number(row.valuePipeline || 0),
      valueCompleted: Number(row.valueCompleted || 0),
    });

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="booking_summary${fnameSuffix ? '_' + fnameSuffix : ''}.xlsx"`,
    );
    const buffer = await wb.xlsx.writeBuffer();
    return res.status(200).send(Buffer.from(buffer));
  } catch (err) {
    next(err);
  }
};
