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
  listRoomBookedRanges,
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

router.get("/:id/bookings", attachUserIfPresent, listRoomBookedRanges);

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

const allowedMimes = new Set(['image/jpeg','image/jpg','image/pjpeg','image/png','image/x-png','image/webp','image/jfif']);
const allowedExts = new Set(['.jpeg','.jpg','.png','.webp','.jfif']);
const fileFilter = (req, file, cb) => {
  const mt = (file.mimetype || '').toLowerCase();
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (allowedMimes.has(mt) || allowedExts.has(ext)) return cb(null, true);
  cb(new Error('Invalid file type. Only JPEG/PNG/WebP allowed'));
};

const upload = multer({ storage, fileFilter, limits: { fileSize: 5 * 1024 * 1024 } });

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
                h.name AS hotel_name,
                COALESCE(
                  (
                    SELECT ri.image_url
                      FROM room_images ri
                     WHERE ri.room_id = r.id
                     ORDER BY ri.id ASC
                     LIMIT 1
                  ),
                  (
                    SELECT hi.image_url
                      FROM hotel_images hi
                     WHERE hi.hotel_id = r.hotel_id
                     ORDER BY hi.id ASC
                     LIMIT 1
                  )
                ) AS image_url
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
                h.name AS hotel_name,
                COALESCE(
                  (
                    SELECT ri.image_url
                      FROM room_images ri
                     WHERE ri.room_id = r.id
                     ORDER BY ri.id ASC
                     LIMIT 1
                  ),
                  (
                    SELECT hi.image_url
                      FROM hotel_images hi
                     WHERE hi.hotel_id = r.hotel_id
                     ORDER BY hi.id ASC
                     LIMIT 1
                  )
                ) AS image_url
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