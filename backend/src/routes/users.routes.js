import { Router } from "express";
import {
  getCurrentProfile,
  updateCurrentProfile,
  getCurrentTransactions,
} from "../controllers/users.controller.js";
import { protect } from "../middleware/auth.js";

const router = Router();

router.use(protect);

router.get("/me", getCurrentProfile);
router.patch("/me", updateCurrentProfile);
router.get("/me/transactions", getCurrentTransactions);

export default router;
