// src/routes/cities.routes.js
import express from "express";
import axios from "axios";

const router = express.Router();

const OTM_BASE = "https://api.opentripmap.com/0.1/en";
const OTM_KEY = process.env.OPENTRIPMAP_KEY;

// --- helpers ---
async function geocodeCity(city) {
  const { data } = await axios.get(`${OTM_BASE}/places/geoname`, {
    params: { name: city, apikey: OTM_KEY },
  });
  return { lat: data.lat, lon: data.lon, label: data.name };
}

async function listPoiByRadius({ lat, lon, radius, limit }) {
  const { data } = await axios.get(`${OTM_BASE}/places/radius`, {
    params: {
      lat, lon, radius,
      kinds: "interesting_places,sightseeing,architecture,museums,monuments,castles,urban_environment,bridges,churches",
      limit, format: "json", apikey: OTM_KEY
    },
  });
  return data;
}

async function poiDetails(xid) {
  const { data } = await axios.get(`${OTM_BASE}/places/xid/${xid}`, {
    params: { apikey: OTM_KEY },
  });
  const title = data.name || data.address?.tourism || data.address?.attraction || "Attraction";
  const image = data.image || data.preview?.source || null;
  return { title, image, kinds: data.kinds, name: data.name, xid: data.xid };
}

// GET /api/cities/:city/attractions/photos?limit=12&radius=10000
router.get("/:city/attractions/photos", async (req, res) => {
  try {
    if (!OTM_KEY) return res.status(500).json({ message: "Missing OPENTRIPMAP_KEY in .env" });

    const city = req.params.city;
    const limit = Math.min(parseInt(req.query.limit || "12", 10), 30);
    const radius = Math.min(parseInt(req.query.radius || "10000", 10), 30000);

    const { lat, lon, label } = await geocodeCity(city);
    const pois = await listPoiByRadius({ lat, lon, radius, limit: limit * 2 });

    const details = await Promise.allSettled(pois.map(p => poiDetails(p.xid)));
    const photos = details
      .filter(r => r.status === "fulfilled" && r.value.image)
      .slice(0, limit)
      .map(r => ({
        title: r.value.title,
        image: r.value.image,
        source: "Wikimedia / OpenTripMap",
        poi: { name: r.value.name, xid: r.value.xid, kinds: r.value.kinds }
      }));

    res.json({ city: label || city, photos });
  } catch (err) {
    console.error(err?.response?.data || err.message);
    res.status(500).json({ message: "Failed to fetch city attractions", error: err.message });
  }
});

export default router;
