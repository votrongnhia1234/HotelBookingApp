import { Router } from "express";
import { createPayment } from "../controllers/payments.controller.js";
import { protect, authorize } from "../middleware/auth.js";

const router = Router();

router.post(
  "/",
  protect,
  authorize("customer", "admin", "hotel_manager"),
  createPayment
);

export default router;
