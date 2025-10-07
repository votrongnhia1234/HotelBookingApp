import { Router } from "express";
import { createBooking, completeBooking, updateBookingStatus } from "../controllers/bookings.controller.js";
import { protect, authorize } from "../middleware/auth.js";

const router = Router();

/** Khách (hoặc admin/manager) tạo booking */
router.post("/", protect, authorize("customer","admin","hotel_manager"), createBooking);

/** Admin/Manager: xác nhận/hủy (khi chưa completed) */
router.patch("/:id/status", protect, authorize("admin","hotel_manager"), updateBookingStatus);

/** Admin/Manager: đánh dấu completed */
router.patch("/:id/complete", protect, authorize("admin","hotel_manager"), completeBooking);

export default router;
