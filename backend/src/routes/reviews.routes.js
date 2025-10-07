import { Router } from "express";
import { listReviews, createReview } from "../controllers/reviews.controller.js";
import { protect, authorize } from "../middleware/auth.js";
const router = Router();

router.get("/", listReviews); // ?hotel_id=&page=&limit=
router.post("/", protect, authorize("customer"), createReview);

export default router;
