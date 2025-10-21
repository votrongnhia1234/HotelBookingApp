import { Router } from "express";
import pool from "../config/db.js";
import {
  getAvailableRooms,
  createRoom,
  updateRoomStatus,
  addRoomImage,
} from "../controllers/rooms.controller.js";
import {
  protect,
  authorize,
  authorizeAdminOrManager,
  authorizeHotelOwnership,
} from "../middleware/auth.js";
import { hotelIdByRoomId } from "../controllers/_ownership.util.js";

const router = Router();

router.get("/available", getAvailableRooms);

router.get("/hotel/:id", async (req, res) => {
  try {
    const hotelId = Number(req.params.id);
    const [rows] = await pool.query(
      `SELECT r.id, r.hotel_id, r.room_number, r.type, r.price_per_night, r.status,
              h.name AS hotel_name
         FROM rooms r
         JOIN hotels h ON r.hotel_id = h.id
        WHERE r.hotel_id = ?
        ORDER BY r.room_number ASC`,
      [hotelId],
    );
    res.json({ data: rows });
  } catch (error) {
    res
      .status(500)
      .json({ message: "Không thể tải danh sách phòng", error: error.message });
  }
});

router.post(
  "/",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership((req) => req.body?.hotel_id ?? req.body?.hotelId),
  createRoom,
);

router.patch(
  "/:id/status",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership((req) => hotelIdByRoomId(Number(req.params.id)), {
    allowNullForAdmin: true,
  }),
  updateRoomStatus,
);

router.post(
  "/images",
  protect,
  authorizeAdminOrManager,
  addRoomImage,
);

router.get(
  "/:id",
  protect,
  authorize("admin", "hotel_manager"),
  async (req, res) => {
    try {
      const id = Number(req.params.id);
      const [rows] = await pool.query(
        `SELECT r.id, r.hotel_id, r.room_number, r.type, r.price_per_night, r.status,
                h.name AS hotel_name
           FROM rooms r
           JOIN hotels h ON r.hotel_id = h.id
          WHERE r.id = ?
          LIMIT 1`,
        [id],
      );
      if (!rows.length) {
        return res.status(404).json({ message: "Room not found" });
      }
      res.json({ data: rows[0] });
    } catch (error) {
      res
        .status(500)
        .json({ message: "Không thể lấy thông tin phòng", error: error.message });
    }
  },
);

export default router;
