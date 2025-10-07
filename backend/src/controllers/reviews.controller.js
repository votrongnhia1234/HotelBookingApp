import pool from "../config/db.js";

/** Lấy đánh giá theo hotel_id */
export const listReviews = async (req, res, next) => {
  try {
    const { hotel_id, page = 1, limit = 20 } = req.query;
    if (!hotel_id) return res.status(400).json({ message: "hotel_id is required" });

    const offset = (Number(page) - 1) * Number(limit);
    const [rows] = await pool.query(
      `SELECT r.id, r.rating, r.comment, r.created_at,
              u.id AS user_id, u.name AS user_name
       FROM reviews r
       JOIN users u ON u.id = r.user_id
       WHERE r.hotel_id = ?
       ORDER BY r.created_at DESC
       LIMIT ? OFFSET ?`,
      [hotel_id, Number(limit), offset]
    );

    res.json({ data: rows, page: Number(page), limit: Number(limit) });
  } catch (e) { next(e); }
};

/** Tạo review (user phải là customer đã có booking của hotel) */
export const createReview = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { hotel_id, rating, comment = "", booking_id = null } = req.body;
    if (!hotel_id || !rating) return res.status(400).json({ message: "hotel_id, rating required" });
    if (rating < 1 || rating > 5) return res.status(400).json({ message: "rating must be 1..5" });

    // xác thực đã từng đặt phòng ở khách sạn này (đã check-in xong)
    const [has] = await pool.query(
      `SELECT 1
         FROM bookings b
         JOIN rooms r ON r.id = b.room_id
         WHERE b.user_id = ? AND r.hotel_id = ? AND b.status IN ('completed')
         LIMIT 1`,
      [userId, hotel_id]
    );
    if (!has.length) return res.status(403).json({ message: "You must complete a stay to review" });

    const [result] = await pool.query(
      `INSERT INTO reviews (user_id, hotel_id, booking_id, rating, comment)
       VALUES (?, ?, ?, ?, ?)`,
      [userId, hotel_id, booking_id, rating, comment]
    );

    res.status(201).json({ id: result.insertId, rating, comment });
  } catch (e) { next(e); }
};
