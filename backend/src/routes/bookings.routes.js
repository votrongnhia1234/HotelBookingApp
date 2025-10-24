import { Router } from "express";
import {
  createBooking,
  listBookings,
  completeBooking,
  updateBookingStatus,
  cancelBooking,
  getBookingSummary,
  exportBookingSummary,
} from "../controllers/bookings.controller.js";
import {
  protect,
  authorize,
  authorizeAdminOrManager,
  authorizeHotelOwnership,
} from "../middleware/auth.js";
import { hotelIdByBookingId } from "../controllers/_ownership.util.js";

const router = Router();

router.get("/", protect, authorize("customer", "admin", "hotel_manager"), listBookings);
router.get(
  "/summary",
  protect,
  authorizeAdminOrManager,
  getBookingSummary,
);
router.get(
  "/summary/export",
  protect,
  authorizeAdminOrManager,
  exportBookingSummary,
);
router.post("/", protect, authorize("customer", "admin", "hotel_manager"), createBooking);
router.patch(
  "/:id/status",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership((req) => hotelIdByBookingId(Number(req.params.id)), {
    allowNullForAdmin: true,
  }),
  updateBookingStatus,
);
router.patch(
  "/:id/complete",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership((req) => hotelIdByBookingId(Number(req.params.id)), {
    allowNullForAdmin: true,
  }),
  completeBooking,
);
router.patch("/:id/cancel", protect, authorize("customer", "admin", "hotel_manager"), cancelBooking);

export default router;
