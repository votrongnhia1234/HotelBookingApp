import express from "express";
import auth from "./auth.routes.js";
import hotels from "./hotels.routes.js";
import rooms from "./rooms.routes.js";
import bookings from "./bookings.routes.js";
import reviews from "./reviews.routes.js";
import payments from "./payments.routes.js";
import vouchers from "./vouchers.routes.js";
import admin from "./admin.routes.js";

// ðŸ”§ THÃŠM DÃ’NG NÃ€Y:
import citiesRouter from "./cities.routes.js";

const router = express.Router();

router.use("/auth", auth);
router.use("/hotels", hotels);
router.use("/rooms", rooms);
router.use("/bookings", bookings);
router.use("/reviews", reviews);
router.use("/payments", payments);
router.use("/vouchers", vouchers);
router.use("/admin", admin);

export default router;
