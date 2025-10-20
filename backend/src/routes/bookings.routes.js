import { Router } from "express";
import {
  createBooking,
  listBookings,
  completeBooking,
  updateBookingStatus,
} from "../controllers/bookings.controller.js";
import { protect, authorize } from "../middleware/auth.js";

const router = Router();

router.get("/", protect, authorize("customer", "admin", "hotel_manager"), listBookings);
router.post("/", protect, authorize("customer", "admin", "hotel_manager"), createBooking);
router.patch("/:id/status", protect, authorize("admin", "hotel_manager"), updateBookingStatus);
router.patch("/:id/complete", protect, authorize("admin", "hotel_manager"), completeBooking);

export default router;
