import { Router } from "express";
import multer from "multer";
import fs from "fs";
import path from "path";
import crypto from "crypto";
import {
  listHotels,
  getHotelCities,
  listManagedHotels,
  addHotelImage,
  uploadHotelImage,
  uploadHotelImagesBulk,
  getHotelImages,
  replaceHotelImage,
  deleteHotelImage,
} from "../controllers/hotels.controller.js";
import { protect, authorizeAdminOrManager } from "../middleware/auth.js";

const router = Router();

router.get("/", listHotels);
router.get("/cities", getHotelCities);
router.get(
  "/managed",
  protect,
  authorizeAdminOrManager,
  listManagedHotels,
);

// Image CRUD for hotels
router.post(
  "/images",
  protect,
  authorizeAdminOrManager,
  addHotelImage,
);

// multipart upload setup
const hotelOriginalsDir = path.join(process.cwd(), "uploads", "hotels", "originals");
fs.mkdirSync(hotelOriginalsDir, { recursive: true });

const hotelStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, hotelOriginalsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const safe = crypto.randomBytes(10).toString("hex");
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

const hotelUpload = multer({ storage: hotelStorage, fileFilter, limits: { fileSize: 5 * 1024 * 1024 } });

router.post(
  "/images/upload",
  protect,
  authorizeAdminOrManager,
  hotelUpload.single("file"),
  uploadHotelImage,
);

router.post(
  "/images/upload-many",
  protect,
  authorizeAdminOrManager,
  hotelUpload.array("files", 20),
  uploadHotelImagesBulk,
);

router.get(
  "/:id/images",
  protect,
  authorizeAdminOrManager,
  getHotelImages,
);

router.patch(
  "/images/:imageId",
  protect,
  authorizeAdminOrManager,
  hotelUpload.single("file"),
  replaceHotelImage,
);

router.delete(
  "/images/:imageId",
  protect,
  authorizeAdminOrManager,
  deleteHotelImage,
);

export default router;