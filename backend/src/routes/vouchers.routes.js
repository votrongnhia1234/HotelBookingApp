import { Router } from "express";
import { listVouchers } from "../controllers/vouchers.controller.js";
import { protect, authorize } from "../middleware/auth.js";

const router = Router();

router.get(
  "/",
  protect,
  authorize("customer", "admin", "hotel_manager"),
  listVouchers,
);

export default router;
