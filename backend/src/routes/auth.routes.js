import { Router } from "express";
import {
  register,
  login,
  loginByPhone,
  loginWithFirebase,
} from "../controllers/auth.controller.js";

const router = Router();

router.post("/register", register);
router.post("/login", login);
router.post("/login-phone", loginByPhone);
router.post("/firebase", loginWithFirebase);

export default router;
