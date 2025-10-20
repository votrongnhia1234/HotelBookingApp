// routes/reviews.routes.js
import { Router } from "express";
import pool from "../config/db.js"; // mysql2/promise pool

const router = Router();

/* Helpers */
const toInt = (v) => {
  if (typeof v === "number" && Number.isFinite(v)) return v | 0;
  if (typeof v === "string") {
    const f = parseFloat(v);
    if (!Number.isNaN(f)) return f | 0;
  }
  return 0;
};

function normalizeBody(req, hotelIdFromParams = null) {
  const b = req.body || {};
  return {
    hotelId:
      hotelIdFromParams ??
      toInt(b.hotelId ?? b.hotel_id ?? b.hotel ?? b.hid),
    userId: toInt(b.userId ?? b.user_id ?? b.uid ?? 0),
    rating: toInt(b.rating ?? b.rate ?? 0),
    comment: (b.comment ?? b.content ?? "").toString(),
  };
}

/* =========================
   GET /api/reviews/hotel/:id
   -> { data: [ {id, hotelId, userId, rating, comment, createdAt}, ... ] }
========================= */
router.get("/hotel/:id", async (req, res) => {
  try {
    const hotelId = toInt(req.params.id);
    const [rows] = await pool.query(
      `SELECT
          id,
          hotel_id AS hotelId,
          user_id AS userId,
          rating,
          comment,
          created_at AS createdAt
       FROM reviews
       WHERE hotel_id = ?
       ORDER BY created_at DESC`,
      [hotelId]
    );
    res.json({ data: rows });
  } catch (err) {
    console.error("GET /reviews/hotel/:id error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/* =========================
   POST tạo review (nhiều alias để tránh 404)
   Chấp nhận:
   - POST /api/reviews                 (body có hotelId, userId, rating, comment)
   - POST /api/reviews/create          (alias)
   - POST /api/reviews/hotel/:id       (hotelId lấy từ params)
========================= */

// Core create handler
async function createReviewHandler(req, res, hotelIdFromParams = null) {
  try {
    const { hotelId, userId, rating, comment } = normalizeBody(
      req,
      hotelIdFromParams
    );

    if (!hotelId || !userId || !rating) {
      return res
        .status(400)
        .json({ message: "hotelId, userId, rating are required" });
    }
    if (rating < 1 || rating > 5) {
      return res.status(400).json({ message: "rating must be 1..5" });
    }

    const [result] = await pool.query(
      `INSERT INTO reviews (hotel_id, user_id, rating, comment)
       VALUES (?, ?, ?, ?)`,
      [hotelId, userId, rating, comment || ""]
    );

    const insertedId = result.insertId;
    const [rows] = await pool.query(
      `SELECT
          id,
          hotel_id AS hotelId,
          user_id AS userId,
          rating,
          comment,
          created_at AS createdAt
       FROM reviews
       WHERE id = ?`,
      [insertedId]
    );

    res.status(201).json({ data: rows[0] });
  } catch (err) {
    console.error("POST /reviews create error:", err);
    res.status(500).json({ message: "Server error" });
  }
}

// POST /api/reviews
router.post("/", (req, res) => createReviewHandler(req, res));

// POST /api/reviews/create  (alias hay gặp)
router.post("/create", (req, res) => createReviewHandler(req, res));

// POST /api/reviews/hotel/:id (lấy hotelId từ params)
router.post("/hotel/:id", (req, res) =>
  createReviewHandler(req, res, toInt(req.params.id))
);

export default router;
