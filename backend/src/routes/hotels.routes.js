import { Router } from "express";
import { listHotels, getHotelCities } from "../controllers/hotels.controller.js";
const router = Router();
router.get("/", listHotels);
router.get("/cities", getHotelCities);
export default router;
