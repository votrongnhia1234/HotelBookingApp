import { Router } from "express";
import { protect, authorize } from "../middleware/auth.js";
import {
  // user management
  listUsers, getUser, createUser, updateUser, changeUserRole, deactivateUser, deleteUser,
  // dashboard stats
  getDashboardStats, revenueByDate, occupancyByHotel, topHotels, usersGrowth,
  // export CSV/Excel
  exportRevenue, exportRevenueSummary,
  // hotel manager assignment
  assignHotelManager, removeHotelManager,
  listHotelsForManager,
  // NEW: list & export hotel managers
  listHotelManagersForHotel, exportHotelManagers,
  // NEW: conversion and cancellations/refunds
  bookingConversion, cancellationsRefunds, exportConversion, exportCancellationsRefunds,
} from "../controllers/admin.controller.js";
import { listBookings } from "../controllers/bookings.controller.js";
import { createHotel, updateHotel, deleteHotel } from "../controllers/hotels.controller.js";

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

/** === Bookings list (alias for admin dashboard) === */
router.get("/bookings", listBookings);

/** === Hotels CRUD (admin only) === */
router.post("/hotels", createHotel);
router.patch("/hotels/:id", updateHotel);
router.delete("/hotels/:id", deleteHotel);

/** === Hotel manager assignment === */
router.post("/hotels/:id/managers", assignHotelManager);
router.delete("/hotels/:id/managers/:userId", removeHotelManager);
// NEW: list hotels for a specific manager + unassigned hotels
router.get("/hotel-managers/:userId/hotels", listHotelsForManager);
// NEW: list managers for a hotel
router.get("/hotels/:id/managers", listHotelManagersForHotel);
// NEW: export mapping (global)
router.get("/hotel-managers/export", exportHotelManagers);
// NEW: export mapping for a single hotel
router.get("/hotels/:id/managers/export", exportHotelManagers);

/** === Dashboard & analytics === */
router.get("/stats/dashboard", getDashboardStats);                   // counters + today overview
router.get("/stats/revenue", revenueByDate);                         // ?from=YYYY-MM-DD&to=YYYY-MM-DD&group=day|month
router.get("/stats/occupancy", occupancyByHotel);                    // ?date=YYYY-MM-DD (hoặc range)
router.get("/stats/top-hotels", topHotels);                          // ?from=&to=&limit=5
router.get("/stats/users-growth", usersGrowth);                      // ?from=&to=&group=month
// Export CSV/Excel
router.get("/stats/revenue/export", exportRevenue);
router.get("/stats/revenue/export-summary", exportRevenueSummary);
router.get("/stats/conversion", bookingConversion);
router.get("/stats/cancellations-refunds", cancellationsRefunds);
router.get("/stats/conversion/export", exportConversion);
router.get("/stats/cancellations-refunds/export", exportCancellationsRefunds);

export default router;
