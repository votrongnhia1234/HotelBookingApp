// src/routes/rooms.routes.js
import { Router } from "express";
import {
  getAvailableRooms,
  createRoom,
  updateRoomStatus,
  addRoomImage,
} from "../controllers/rooms.controller.js";

// ⬇️ QUAN TRỌNG: import middleware
import { protect, authorize } from "../middleware/auth.js";

const router = Router();

// public
router.get("/available", getAvailableRooms);

// only admin + hotel_manager
router.post("/", protect, authorize("admin", "hotel_manager"), createRoom);
router.patch("/:id/status", protect, authorize("admin", "hotel_manager"), updateRoomStatus);
router.post("/images", protect, authorize("admin", "hotel_manager"), addRoomImage);

export default router;
