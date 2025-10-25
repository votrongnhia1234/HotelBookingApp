import fs from "fs";
import path from "path";
import sharp from "sharp";
import pool from "../config/db.js";
import { managerOwnsHotel } from "./_ownership.util.js";
import { recordAudit } from "../utils/audit.js";

export const listHotels = async (req, res, next) => {
  try {
    const { q, city, page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    const filters = [];
    const params = [];

    if (q) { filters.push("(name LIKE ? OR description LIKE ?)"); params.push(`%${q}%`, `%${q}%`); }
    if (city) { filters.push("city = ?"); params.push(city); }

    const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";

    const [rows] = await pool.query(
      `SELECT h.id, h.name, h.description, h.address, h.city, h.country, h.rating, h.created_at,
              (
                SELECT hi.image_url
                  FROM hotel_images hi
                 WHERE hi.hotel_id = h.id
                 ORDER BY hi.id ASC
                 LIMIT 1
              ) AS image_url,
              (
                SELECT COUNT(*) FROM hotel_managers hm WHERE hm.hotel_id = h.id
              ) AS manager_count
         FROM hotels h
         ${where}
         ORDER BY h.created_at DESC
         LIMIT ? OFFSET ?`,
      [...params, Number(limit), offset]
    );

    res.json({ data: rows, page: Number(page), limit: Number(limit) });
  } catch (e) { next(e); }
};

export const listManagedHotels = async (req, res, next) => {
  try {
    const role = req.user?.role;
    if (!role) return res.status(401).json({ message: "Unauthorized" });

    if (role === "admin") {
      const [rows] = await pool.query(
        `SELECT h.id, h.name, h.description, h.address, h.city, h.country, h.rating,
                h.created_at
           FROM hotels h
          ORDER BY h.name ASC`,
      );
      return res.json({ data: rows });
    }

    if (role !== "hotel_manager") {
      return res.status(403).json({ message: "Forbidden" });
    }

    const [rows] = await pool.query(
      `SELECT h.id, h.name, h.description, h.address, h.city, h.country, h.rating,
              hm.created_at AS manager_since
         FROM hotel_managers hm
         JOIN hotels h ON h.id = hm.hotel_id
        WHERE hm.user_id = ?
        ORDER BY h.name ASC`,
      [req.user.id],
    );

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};

export const getHotelCities = async (req, res, next) => {
  try {
    const { q, limit } = req.query;
    const params = [];
    let sql =
      `SELECT city, COUNT(*) AS hotels
       FROM hotels
       WHERE city IS NOT NULL AND city <> ''`;

    if (q && q.trim()) {
      sql += ` AND city LIKE ?`;
      params.push(`%${q.trim()}%`);
    }

    sql += ` GROUP BY city
             HAVING hotels > 0
             ORDER BY city ASC`;

    if (limit && /^\d+$/.test(String(limit))) {
      sql += ` LIMIT ?`;
      params.push(Number(limit));
    }

    const [rows] = await pool.query(sql, params);

    // Chuẩn hoá về mảng [{city, hotels}]
    const data = rows.map(r => ({
      city: String(r.city),
      hotels: Number(r.hotels),
    }));

    res.json({ data, total: data.length });
  } catch (err) {
    next(err);
  }
};

const HOTEL_UPLOAD_ROOT = path.join(process.cwd(), "uploads", "hotels");
const HOTEL_ORIGINALS_DIR = path.join(HOTEL_UPLOAD_ROOT, "originals");
const HOTEL_THUMBS_DIR = path.join(HOTEL_UPLOAD_ROOT, "thumbs");

function ensureHotelUploadDirs() {
  fs.mkdirSync(HOTEL_ORIGINALS_DIR, { recursive: true });
  fs.mkdirSync(HOTEL_THUMBS_DIR, { recursive: true });
}

function removeStoredHotelImage(imageUrl) {
  if (!imageUrl) return;
  const fileName = imageUrl.split("/").pop();
  if (!fileName) return;

  const thumbPath = path.join(HOTEL_THUMBS_DIR, fileName);
  const originalName = fileName.startsWith("thumb-") ? fileName.substring(6) : fileName;
  const originalPath = path.join(HOTEL_ORIGINALS_DIR, originalName);

  for (const filePath of [thumbPath, originalPath]) {
    fs.promises
      .access(filePath, fs.constants.F_OK)
      .then(() => fs.promises.unlink(filePath))
      .catch(() => {});
  }
}

export const addHotelImage = async (req, res, next) => {
  try {
    const { hotel_id, image_url } = req.body;
    if (!hotel_id || !image_url) return res.status(400).json({ message: "hotel_id and image_url required" });

    await pool.query(`INSERT INTO hotel_images (hotel_id, image_url) VALUES (?, ?)`, [hotel_id, image_url]);
    await recordAudit({ userId: req.user?.id ?? null, action: "hotel_image_add", targetType: "hotel", targetId: Number(hotel_id), metadata: { image_url } });
    res.status(201).json({ message: "Image added" });
  } catch (e) { next(e); }
};

export const uploadHotelImage = async (req, res, next) => {
  try {
    const file = req.file;
    const hotelId = req.body.hotel_id;
    if (!file) return res.status(400).json({ message: 'file is required' });
    if (!hotelId) return res.status(400).json({ message: 'hotel_id is required' });

    if (req.user?.role === "hotel_manager") {
      const ok = await managerOwnsHotel(req.user.id, Number(hotelId));
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    ensureHotelUploadDirs();

    const originalFilename = file.filename;
    const originalPath = path.join(HOTEL_ORIGINALS_DIR, originalFilename);
    const thumbFilename = `thumb-${originalFilename}`;
    const thumbPath = path.join(HOTEL_THUMBS_DIR, thumbFilename);

    await sharp(originalPath).resize(300, 200, { fit: "cover" }).toFile(thumbPath);

    const originalUrl = `/uploads/hotels/originals/${originalFilename}`;
    const thumbUrl = `/uploads/hotels/thumbs/${thumbFilename}`;

    const [result] = await pool.query(
      `INSERT INTO hotel_images (hotel_id, image_url) VALUES (?, ?)`,
      [hotelId, thumbUrl],
    );

    await recordAudit({ userId: req.user?.id ?? null, action: "hotel_image_upload", targetType: "hotel", targetId: Number(hotelId), metadata: { id: result.insertId, image_url: thumbUrl, original_url: originalUrl } });

    res.status(201).json({ message: 'Image uploaded', image_url: thumbUrl, original_url: originalUrl, id: result.insertId });
  } catch (e) { next(e); }
};

export const uploadHotelImagesBulk = async (req, res, next) => {
  try {
    const files = req.files || [];
    const hotelId = req.body.hotel_id;
    if (!hotelId) return res.status(400).json({ message: 'hotel_id is required' });
    if (!files.length) return res.status(400).json({ message: 'files are required' });

    if (req.user?.role === "hotel_manager") {
      const ok = await managerOwnsHotel(req.user.id, Number(hotelId));
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    ensureHotelUploadDirs();

    const results = [];
    for (const file of files) {
      const originalFilename = file.filename;
      const originalPath = path.join(HOTEL_ORIGINALS_DIR, originalFilename);
      const thumbFilename = `thumb-${originalFilename}`;
      const thumbPath = path.join(HOTEL_THUMBS_DIR, thumbFilename);

      await sharp(originalPath).resize(300, 200, { fit: 'cover' }).toFile(thumbPath);

      const originalUrl = `/uploads/hotels/originals/${originalFilename}`;
      const thumbUrl = `/uploads/hotels/thumbs/${thumbFilename}`;

      const [insert] = await pool.query(
        `INSERT INTO hotel_images (hotel_id, image_url) VALUES (?, ?)`,
        [hotelId, thumbUrl],
      );

      results.push({ id: insert.insertId, image_url: thumbUrl, original_url: originalUrl });
      await recordAudit({ userId: req.user?.id ?? null, action: "hotel_image_upload_bulk_item", targetType: "hotel", targetId: Number(hotelId), metadata: { id: insert.insertId, image_url: thumbUrl, original_url: originalUrl } });
    }

    res.status(201).json({ message: 'Images uploaded', images: results });
  } catch (e) { next(e); }
};

export const getHotelImages = async (req, res, next) => {
  try {
    const hotelId = Number(req.params.id ?? req.body?.hotel_id ?? req.query?.hotel_id);
    if (!Number.isInteger(hotelId) || hotelId <= 0) {
      return res.status(400).json({ message: "hotel id must be a positive integer" });
    }

    if (req.user?.role === "hotel_manager") {
      const owns = await managerOwnsHotel(req.user.id, hotelId);
      if (!owns) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    const [rows] = await pool.query(
      `SELECT id, hotel_id, image_url, created_at
         FROM hotel_images
        WHERE hotel_id = ?
        ORDER BY id ASC`,
      [hotelId],
    );

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};

export const replaceHotelImage = async (req, res, next) => {
  try {
    const imageId = Number(req.params.imageId);
    if (!Number.isInteger(imageId) || imageId <= 0) {
      return res.status(400).json({ message: "image id must be a positive integer" });
    }

    const file = req.file;
    if (!file) return res.status(400).json({ message: "file is required" });

    const [[existing]] = await pool.query(
      `SELECT hi.id, hi.hotel_id, hi.image_url
         FROM hotel_images hi
        WHERE hi.id = ?
        LIMIT 1`,
      [imageId],
    );
    if (!existing) {
      return res.status(404).json({ message: "Image not found" });
    }

    if (req.user?.role === "hotel_manager") {
      const owns = await managerOwnsHotel(req.user.id, existing.hotel_id);
      if (!owns) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    ensureHotelUploadDirs();

    const originalFilename = file.filename;
    const originalPath = path.join(HOTEL_ORIGINALS_DIR, originalFilename);
    const thumbFilename = `thumb-${originalFilename}`;
    const thumbPath = path.join(HOTEL_THUMBS_DIR, thumbFilename);

    await sharp(originalPath).resize(300, 200, { fit: "cover" }).toFile(thumbPath);
    const originalUrl = `/uploads/hotels/originals/${originalFilename}`;
    const thumbUrl = `/uploads/hotels/thumbs/${thumbFilename}`;

    await pool.query(
      "UPDATE hotel_images SET image_url = ? WHERE id = ?",
      [thumbUrl, imageId],
    );

    removeStoredHotelImage(existing.image_url);

    res.json({
      message: "Image updated",
      image_url: thumbUrl,
      original_url: originalUrl,
    });
  } catch (err) {
    next(err);
  }
};

export const deleteHotelImage = async (req, res, next) => {
  try {
    const imageId = Number(req.params.imageId);
    if (!Number.isInteger(imageId) || imageId <= 0) {
      return res.status(400).json({ message: "image id must be a positive integer" });
    }

    const [[existing]] = await pool.query(
      `SELECT hi.id, hi.hotel_id, hi.image_url
         FROM hotel_images hi
        WHERE hi.id = ?
        LIMIT 1`,
      [imageId],
    );
    if (!existing) {
      return res.status(404).json({ message: "Image not found" });
    }

    if (req.user?.role === "hotel_manager") {
      const owns = await managerOwnsHotel(req.user.id, existing.hotel_id);
      if (!owns) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    await pool.query("DELETE FROM hotel_images WHERE id = ?", [imageId]);

    removeStoredHotelImage(existing.image_url);

    await recordAudit({ userId: req.user?.id ?? null, action: "hotel_image_delete", targetType: "hotel_image", targetId: imageId });

    res.json({ message: "Image removed" });
  } catch (err) {
    next(err);
  }
};

// === Admin: CRUD Hotels ===
export const createHotel = async (req, res, next) => {
  try {
    if (req.user?.role !== "admin") {
      return res.status(403).json({ message: "Forbidden" });
    }

    const {
      name,
      description,
      address,
      city,
      country,
      rating,
      latitude,
      longitude,
      image_url,
    } = req.body;

    const nameTrimmed = (name || "").trim();
    if (!nameTrimmed) {
      return res.status(400).json({ message: "name is required" });
    }

    let ratingVal = null;
    if (rating !== undefined && rating !== null && rating !== "") {
      const r = Number(rating);
      if (!Number.isFinite(r) || r < 0 || r > 5) {
        return res.status(400).json({ message: "rating must be a number between 0 and 5" });
      }
      ratingVal = r;
    }

    const latVal = latitude !== undefined ? (latitude === null ? null : Number(latitude)) : null;
    const lngVal = longitude !== undefined ? (longitude === null ? null : Number(longitude)) : null;

    const [insert] = await pool.query(
      `INSERT INTO hotels (name, description, address, city, country, rating)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        nameTrimmed,
        description ?? null,
        address ?? null,
        city ?? null,
        country ?? null,
        ratingVal,
      ]
    );

    const hotelId = insert.insertId;
    const [[hotel]] = await pool.query(
      `SELECT id, name, description, address, city, country, rating, created_at
         FROM hotels WHERE id = ? LIMIT 1`,
      [hotelId]
    );

    return res.status(201).json({ message: "Hotel created", data: hotel });
  } catch (err) {
    next(err);
  }
};

export const updateHotel = async (req, res, next) => {
  try {
    if (req.user?.role !== "admin") {
      return res.status(403).json({ message: "Forbidden" });
    }

    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ message: "Invalid hotel id" });
    }

    const fields = [];
    const params = [];

    if (req.body.name !== undefined) {
      const nameTrimmed = String(req.body.name || "").trim();
      if (!nameTrimmed) return res.status(400).json({ message: "name cannot be empty" });
      fields.push("name = ?");
      params.push(nameTrimmed);
    }
    ["description","address","city","country","image_url"].forEach((k) => {
      if (req.body[k] !== undefined) {
        fields.push(`${k} = ?`);
        params.push(req.body[k] === null ? null : req.body[k]);
      }
    });

    if (req.body.rating !== undefined) {
      if (req.body.rating === null || req.body.rating === "") {
        fields.push("rating = NULL");
      } else {
        const r = Number(req.body.rating);
        if (!Number.isFinite(r) || r < 0 || r > 5) {
          return res.status(400).json({ message: "rating must be a number between 0 and 5" });
        }
        fields.push("rating = ?");
        params.push(r);
      }
    }

    if (req.body.latitude !== undefined) {
      const latVal = req.body.latitude === null ? null : Number(req.body.latitude);
      fields.push("latitude = ?");
      params.push(Number.isFinite(latVal) ? latVal : null);
    }
    if (req.body.longitude !== undefined) {
      const lngVal = req.body.longitude === null ? null : Number(req.body.longitude);
      fields.push("longitude = ?");
      params.push(Number.isFinite(lngVal) ? lngVal : null);
    }

    if (!fields.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    params.push(id);

    const [r] = await pool.query(`UPDATE hotels SET ${fields.join(", ")} WHERE id = ?`, params);
    if (r.affectedRows === 0) {
      return res.status(404).json({ message: "Hotel not found" });
    }

    const [[hotel]] = await pool.query(
      `SELECT id, name, description, address, city, country, rating, latitude, longitude, image_url, created_at, updated_at
         FROM hotels WHERE id = ? LIMIT 1`,
      [id]
    );

    return res.json({ message: "Hotel updated", data: hotel });
  } catch (err) {
    next(err);
  }
};

export const deleteHotel = async (req, res, next) => {
  try {
    if (req.user?.role !== "admin") {
      return res.status(403).json({ message: "Forbidden" });
    }

    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ message: "Invalid hotel id" });
    }

    const [r] = await pool.query(`DELETE FROM hotels WHERE id = ?`, [id]);
    if (r.affectedRows === 0) {
      return res.status(404).json({ message: "Hotel not found" });
    }

    return res.json({ message: "Hotel deleted" });
  } catch (err) {
    next(err);
  }
};
