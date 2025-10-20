import { Router } from "express";
import { register, login, loginWithFirebase } from "../controllers/auth.controller.js";

const router = Router();

router.post("/register", register);
router.post("/login", login);
router.post("/firebase", loginWithFirebase);

export default router;
