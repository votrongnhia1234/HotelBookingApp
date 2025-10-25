import { Router } from "express";
import { createPayment, handleStripeWebhook, confirmPaymentDemo } from "../controllers/payments.controller.js";
import { protect, authorize } from "../middleware/auth.js";
import { validateBody } from "../middleware/validate.js";
import { createPaymentSchema, confirmPaymentDemoSchema } from "../schemas/payments.schema.js";

const router = Router();

router.post(
  "/",
  protect,
  authorize("customer", "admin", "hotel_manager"),
  validateBody(createPaymentSchema),
  createPayment
);
router.post(
  "/confirm-demo",
  protect,
  authorize("customer", "admin", "hotel_manager"),
  validateBody(confirmPaymentDemoSchema),
  confirmPaymentDemo
);

export const stripeWebhookHandler = handleStripeWebhook;

export default router;
