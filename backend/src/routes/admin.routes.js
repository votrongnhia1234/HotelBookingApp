import { Router } from "express";
import { protect, authorize } from "../middleware/auth.js";
import {
  // user management
  listUsers, getUser, createUser, updateUser, changeUserRole, deactivateUser, deleteUser,
  // dashboard stats
  getDashboardStats, revenueByDate, occupancyByHotel, topHotels, usersGrowth,
  // export CSV/Excel
  exportRevenue
} from "../controllers/admin.controller.js";

const router = Router();

// RBAC: admin only
router.use(protect, authorize("admin"));

/** === Users management === */
router.get("/users", listUsers);
router.get("/users/:id", getUser);
router.post("/users", createUser);
router.patch("/users/:id", updateUser);
router.patch("/users/:id/role", changeUserRole);
router.patch("/users/:id/deactivate", deactivateUser);
router.delete("/users/:id", deleteUser);

/** === Dashboard & analytics === */
router.get("/stats/dashboard", getDashboardStats);                   // counters + today overview
router.get("/stats/revenue", revenueByDate);                         // ?from=YYYY-MM-DD&to=YYYY-MM-DD&group=day|month
router.get("/stats/occupancy", occupancyByHotel);                    // ?date=YYYY-MM-DD (hoặc range)
router.get("/stats/top-hotels", topHotels);                          // ?from=&to=&limit=5
router.get("/stats/users-growth", usersGrowth);                      // ?from=&to=&group=month
// Export CSV/Excel
router.get("/stats/revenue/export", exportRevenue);


export default router;
