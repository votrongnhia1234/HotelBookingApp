import { Router } from "express";
import pool from "../config/db.js"; // kiểm tra đường dẫn đúng với db.js

const router = Router();

// 🆕 Route: lấy danh sách phòng theo hotel_id
router.get("/hotel/:id", async (req, res) => {
  try {
    const hotelId = Number(req.params.id);
    const [rows] = await pool.query(
      `SELECT r.id, r.room_number, r.type, r.price_per_night, r.status,
              h.name AS hotel_name
         FROM rooms r
         JOIN hotels h ON r.hotel_id = h.id
        WHERE r.hotel_id = ?`,
      [hotelId]
    );
    res.json({ data: rows });
  } catch (error) {
    res.status(500).json({ message: "Không thể tải danh sách phòng", error: error.message });
  }
});

export default router;
