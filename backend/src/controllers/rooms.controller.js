import pool from "../config/db.js";
import { managerOwnsHotel, hotelIdByRoomId } from "./_ownership.util.js";


/**
 * Tìm phòng trống theo khoảng ngày (check_in, check_out)
 * Điều kiện không trống nếu có booking overlap (không CANCELLED)
 * overlap khi: (new_in < b.check_out) AND (new_out > b.check_in)
 */
export const getAvailableRooms = async (req, res, next) => {
  try {
    const { hotel_id, check_in, check_out } = req.query;
    if (!check_in || !check_out) {
      return res.status(400).json({ message: "check_in and check_out are required (YYYY-MM-DD)" });
    }
    if (check_in >= check_out) {
      return res.status(400).json({ message: "check_in must be before check_out" });
    }

    const params = [check_out, check_in];
    let hotelFilter = "";
    if (hotel_id) { hotelFilter = "AND r.hotel_id = ?"; params.push(hotel_id); }

    const sql = `
      SELECT r.id, r.hotel_id, r.room_number, r.type, r.price_per_night, r.status,
             h.name AS hotel_name, h.city, h.country
      FROM rooms r
      JOIN hotels h ON h.id = r.hotel_id
      LEFT JOIN bookings b
        ON b.room_id = r.id
       AND b.status IN ('pending','confirmed','completed')
       AND (? > b.check_in AND ? < b.check_out)
      WHERE r.status <> 'maintenance'
        ${hotelFilter}
        AND b.id IS NULL
      ORDER BY r.price_per_night ASC
    `;

    const [rows] = await pool.query(sql, params);

    // kèm ảnh đại diện
    const roomIds = rows.map(r => r.id);
    let imagesByRoom = {};
    if (roomIds.length) {
      const [imgs] = await pool.query(
        `SELECT room_id, MIN(image_url) AS image_url
         FROM room_images
         WHERE room_id IN (${roomIds.map(() => "?").join(",")})
         GROUP BY room_id`, roomIds
      );
      imagesByRoom = Object.fromEntries(imgs.map(x => [x.room_id, x.image_url]));
    }

    const data = rows.map(r => ({ ...r, image_url: imagesByRoom[r.id] || null }));
    res.json({ data, total: data.length });
  } catch (e) { next(e); }
};

export const createRoom = async (req, res, next) => {
  try {
    const { hotel_id, room_number, type, price_per_night, status = "available" } = req.body;
    if (!hotel_id || !room_number || !type || !price_per_night)
      return res.status(400).json({ message: "hotel_id, room_number, type, price_per_night required" });

    // ⬇️ Chỉ chặn khi là hotel_manager
    if (req.user?.role === "hotel_manager") {
      const ok = await managerOwnsHotel(req.user.id, Number(hotel_id));
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    await pool.query(
      `INSERT INTO rooms (hotel_id, room_number, type, price_per_night, status)
       VALUES (?, ?, ?, ?, ?)`,
      [hotel_id, room_number, type, price_per_night, status]
    );
    res.status(201).json({ message: "Room created" });
  } catch (e) { next(e); }
};

export const updateRoomStatus = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { status } = req.body;
    if (!["available","booked","maintenance"].includes(status))
      return res.status(400).json({ message: "Invalid status" });

    // ⬇️ kiểm tra sở hữu KS của room này
    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByRoomId(id);
      if (!hotelId) return res.status(404).json({ message: "Room not found" });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    const [r] = await pool.query("UPDATE rooms SET status=? WHERE id=?", [status, id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "Room not found" });
    res.json({ message: "Room status updated" });
  } catch (e) { next(e); }
};

export const addRoomImage = async (req, res, next) => {
  try {
    const { room_id, image_url } = req.body;
    if (!room_id || !image_url) return res.status(400).json({ message: "room_id and image_url required" });

    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByRoomId(Number(room_id));
      if (!hotelId) return res.status(404).json({ message: "Room not found" });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    await pool.query(`INSERT INTO room_images (room_id, image_url) VALUES (?, ?)`, [room_id, image_url]);
    res.status(201).json({ message: "Image added" });
  } catch (e) { next(e); }
};

