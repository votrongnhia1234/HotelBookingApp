import { Router } from "express";
import pool from "../config/db.js";
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import {
  getAvailableRooms,
  listRoomsByHotel,
  createRoom,
  updateRoomStatus,
  addRoomImage,
  uploadRoomImage,
  getRoomImages,
  replaceRoomImage,
  deleteRoomImage,
  uploadRoomImagesBulk,
} from "../controllers/rooms.controller.js";
import {
  protect,
  authorize,
  authorizeAdminOrManager,
  authorizeHotelOwnership,
  attachUserIfPresent,
} from "../middleware/auth.js";
import { hotelIdByRoomId } from "../controllers/_ownership.util.js";

const router = Router();

router.get("/available", getAvailableRooms);

router.get("/hotel/:id", attachUserIfPresent, listRoomsByHotel);

router.get(
  "/managed/:id",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership((req) => Number(req.params.id)),
  listRoomsByHotel,
);

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

// multipart file upload: single file field 'file'
const originalsDir = path.join(process.cwd(), 'uploads', 'rooms', 'originals');
fs.mkdirSync(originalsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, originalsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const safe = crypto.randomBytes(10).toString('hex');
    const name = `${Date.now()}-${safe}${ext}`;
    cb(null, name);
  },
});

const upload = multer({ storage });

router.post(
  "/images/upload",
  protect,
  authorizeAdminOrManager,
  upload.single('file'),
  uploadRoomImage,
);

router.post(
  "/images/upload-many",
  protect,
  authorizeAdminOrManager,
  upload.array('files', 20),
  uploadRoomImagesBulk,
);
router.get(
  "/:id/images",
  protect,
  authorizeAdminOrManager,
  getRoomImages,
);

router.patch(
  "/images/:imageId",
  protect,
  authorizeAdminOrManager,
  upload.single('file'),
  replaceRoomImage,
);

router.delete(
  "/images/:imageId",
  protect,
  authorizeAdminOrManager,
  deleteRoomImage,
);

router.get(
  "/public/:id",
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

// protected admin/manager-only detail route kept for management use
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
