import { Router } from "express";
import {
  listVouchers,
  createVoucher,
  updateVoucher,
  deleteVoucher,
} from "../controllers/vouchers.controller.js";
import {
  protect,
  authorize,
  authorizeAdmin,
  authorizeAdminOrManager,
  authorizeHotelOwnership,
} from "../middleware/auth.js";
import { hotelIdByVoucherId } from "../controllers/_ownership.util.js";

const router = Router();

router.get(
  "/",
  protect,
  authorize("customer", "admin", "hotel_manager"),
  listVouchers,
);
router.post(
  "/",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership((req) => req.body?.hotelId ?? req.body?.hotel_id ?? null),
  createVoucher,
);
router.patch(
  "/:id",
  protect,
  authorizeAdminOrManager,
  authorizeHotelOwnership(
    async (req) =>
      req.body?.hotelId ??
      req.body?.hotel_id ??
      (await hotelIdByVoucherId(Number(req.params.id))),
    { allowNullForAdmin: true },
  ),
  updateVoucher,
);
router.delete(
  "/:id",
  protect,
  authorizeAdmin,
  deleteVoucher,
);

export default router;
