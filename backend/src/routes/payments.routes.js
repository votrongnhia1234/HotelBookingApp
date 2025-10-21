import { Router } from "express";
import { createPayment, handleStripeWebhook } from "../controllers/payments.controller.js";
import { protect, authorize } from "../middleware/auth.js";

const router = Router();

router.post("/", protect, authorize("customer", "admin", "hotel_manager"), createPayment);

export const stripeWebhookHandler = handleStripeWebhook;

export default router;
