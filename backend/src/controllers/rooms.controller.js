import fs from "fs";
import path from "path";
import sharp from "sharp";
import pool from "../config/db.js";
import { managerOwnsHotel, hotelIdByRoomId } from "./_ownership.util.js";

const UPLOAD_ROOT = path.join(process.cwd(), "uploads", "rooms");
const ORIGINALS_DIR = path.join(UPLOAD_ROOT, "originals");
const THUMBS_DIR = path.join(UPLOAD_ROOT, "thumbs");

function ensureUploadDirs() {
  fs.mkdirSync(ORIGINALS_DIR, { recursive: true });
  fs.mkdirSync(THUMBS_DIR, { recursive: true });
}

function removeStoredImage(imageUrl) {
  if (!imageUrl) return;
  const fileName = imageUrl.split("/").pop();
  if (!fileName) return;

  const thumbPath = path.join(THUMBS_DIR, fileName);
  const originalName = fileName.startsWith("thumb-")
    ? fileName.substring(6)
    : fileName;
  const originalPath = path.join(ORIGINALS_DIR, originalName);

  for (const filePath of [thumbPath, originalPath]) {
    fs.promises
      .access(filePath, fs.constants.F_OK)
      .then(() => fs.promises.unlink(filePath))
      .catch(() => {});
  }
}

/**
 * Tìm phòng trống theo khoảng ngày (check_in, check_out)
 * Điều kiện không trống nếu có booking overlap (không CANCELLED)
 * overlap khi: (new_in < b.check_out) AND (new_out > b.check_in)
 */
export const getAvailableRooms = async (req, res, next) => {
  try {
    const { hotel_id, check_in, check_out } = req.query;
    if (!check_in || !check_out) {
      return res.status(400).json({ message: "check_in and check_out are required (YYYY-MM-DD)" });
    }
    if (check_in >= check_out) {
      return res.status(400).json({ message: "check_in must be before check_out" });
    }

    const params = [check_out, check_in];
    let hotelFilter = "";
    if (hotel_id) { hotelFilter = "AND r.hotel_id = ?"; params.push(hotel_id); }

    const sql = `
      SELECT r.id, r.hotel_id, r.room_number, r.type, r.price_per_night, r.status,
             h.name AS hotel_name, h.city, h.country
      FROM rooms r
      JOIN hotels h ON h.id = r.hotel_id
      LEFT JOIN bookings b
        ON b.room_id = r.id
       AND b.status IN ('pending','confirmed','completed')
       AND (? > b.check_in AND ? < b.check_out)
      WHERE r.status <> 'maintenance'
        ${hotelFilter}
        AND b.id IS NULL
      ORDER BY r.price_per_night ASC
    `;

    const [rows] = await pool.query(sql, params);

    // kèm ảnh đại diện
    const roomIds = rows.map(r => r.id);
    let imagesByRoom = {};
    if (roomIds.length) {
      const [imgs] = await pool.query(
        `SELECT room_id, MIN(image_url) AS image_url
         FROM room_images
         WHERE room_id IN (${roomIds.map(() => "?").join(",")})
         GROUP BY room_id`, roomIds
      );
      imagesByRoom = Object.fromEntries(imgs.map(x => [x.room_id, x.image_url]));
    }

    const data = rows.map(r => ({ ...r, image_url: imagesByRoom[r.id] || null }));
    res.json({ data, total: data.length });
  } catch (e) { next(e); }
};

export const listRoomsByHotel = async (req, res, next) => {
  try {
    const hotelId = Number(req.params.id ?? req.body?.hotel_id ?? req.query?.hotel_id);
    if (!Number.isInteger(hotelId) || hotelId <= 0) {
      return res.status(400).json({ message: "hotel_id must be a positive integer" });
    }

    if (req.user?.role === "hotel_manager") {
      const owns = await managerOwnsHotel(req.user.id, hotelId);
      if (!owns) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    const [rows] = await pool.query(
      `SELECT r.id,
              r.hotel_id,
              r.room_number,
              r.type,
              r.price_per_night,
              r.status,
              (
                SELECT ri.image_url
                  FROM room_images ri
                 WHERE ri.room_id = r.id
                 ORDER BY ri.id ASC
                 LIMIT 1
              ) AS image_url
         FROM rooms r
        WHERE r.hotel_id = ?
        ORDER BY r.room_number ASC`,
      [hotelId],
    );

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};

export const createRoom = async (req, res, next) => {
  try {
    const { hotel_id, room_number, type, price_per_night, status = "available" } = req.body;
    if (!hotel_id || !room_number || !type || !price_per_night) {
      return res
        .status(400)
        .json({ message: "hotel_id, room_number, type, price_per_night required" });
    }

    if (req.user?.role === "hotel_manager") {
      const ok = await managerOwnsHotel(req.user.id, Number(hotel_id));
      if (!ok) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    const [result] = await pool.query(
      `INSERT INTO rooms (hotel_id, room_number, type, price_per_night, status)
       VALUES (?, ?, ?, ?, ?)`,
      [hotel_id, room_number, type, price_per_night, status],
    );
    res.status(201).json({ message: "Room created", id: result.insertId });
  } catch (e) {
    if (e?.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Room already exists for this hotel." });
    }
    next(e);
  }
};

export const updateRoomStatus = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { status } = req.body;
    if (!["available","booked","maintenance"].includes(status))
      return res.status(400).json({ message: "Invalid status" });

    // ⬇️ kiểm tra sở hữu KS của room này
    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByRoomId(id);
      if (!hotelId) return res.status(404).json({ message: "Room not found" });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    const [r] = await pool.query("UPDATE rooms SET status=? WHERE id=?", [status, id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "Room not found" });
    res.json({ message: "Room status updated" });
  } catch (e) { next(e); }
};

export const addRoomImage = async (req, res, next) => {
  try {
    const { room_id, image_url } = req.body;
    if (!room_id || !image_url) return res.status(400).json({ message: "room_id and image_url required" });

    if (req.user?.role === "hotel_manager") {
      const hotelId = await hotelIdByRoomId(Number(room_id));
      if (!hotelId) return res.status(404).json({ message: "Room not found" });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: "You are not allowed to manage this hotel" });
    }

    await pool.query(`INSERT INTO room_images (room_id, image_url) VALUES (?, ?)`, [room_id, image_url]);
    res.status(201).json({ message: "Image added" });
  } catch (e) { next(e); }
};

export const uploadRoomImage = async (req, res, next) => {
  try {
    const file = req.file;
    const roomId = req.body.room_id;
    if (!file) return res.status(400).json({ message: 'file is required' });
    if (!roomId) return res.status(400).json({ message: 'room_id is required' });

    if (req.user?.role === 'hotel_manager') {
      const hotelId = await hotelIdByRoomId(Number(roomId));
      if (!hotelId) return res.status(404).json({ message: 'Room not found' });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: 'You are not allowed to manage this hotel' });
    }

    ensureUploadDirs();

    const originalFilename = file.filename;
    const originalPath = path.join(ORIGINALS_DIR, originalFilename);
    const thumbFilename = `thumb-${originalFilename}`;
    const thumbPath = path.join(THUMBS_DIR, thumbFilename);

    await sharp(originalPath).resize(300, 200, { fit: 'cover' }).toFile(thumbPath);

    const originalUrl = `/uploads/rooms/originals/${originalFilename}`;
    const thumbUrl = `/uploads/rooms/thumbs/${thumbFilename}`;

    const [result] = await pool.query(
      `INSERT INTO room_images (room_id, image_url) VALUES (?, ?)`,
      [roomId, thumbUrl],
    );

    res.status(201).json({
      message: 'Image uploaded',
      image_url: thumbUrl,
      original_url: originalUrl,
      id: result.insertId,
    });
  } catch (e) { next(e); }
};

export const uploadRoomImagesBulk = async (req, res, next) => {
  try {
    const files = req.files || [];
    const roomId = req.body.room_id;
    if (!roomId) return res.status(400).json({ message: 'room_id is required' });
    if (!files.length) return res.status(400).json({ message: 'files are required' });

    if (req.user?.role === 'hotel_manager') {
      const hotelId = await hotelIdByRoomId(Number(roomId));
      if (!hotelId) return res.status(404).json({ message: 'Room not found' });
      const ok = await managerOwnsHotel(req.user.id, hotelId);
      if (!ok) return res.status(403).json({ message: 'You are not allowed to manage this hotel' });
    }

    ensureUploadDirs();

    const results = [];
    for (const file of files) {
      const originalFilename = file.filename;
      const originalPath = path.join(ORIGINALS_DIR, originalFilename);
      const thumbFilename = `thumb-${originalFilename}`;
      const thumbPath = path.join(THUMBS_DIR, thumbFilename);

      await sharp(originalPath).resize(300, 200, { fit: 'cover' }).toFile(thumbPath);

      const originalUrl = `/uploads/rooms/originals/${originalFilename}`;
      const thumbUrl = `/uploads/rooms/thumbs/${thumbFilename}`;

      const [insert] = await pool.query(
        `INSERT INTO room_images (room_id, image_url) VALUES (?, ?)`,
        [roomId, thumbUrl],
      );

      results.push({ id: insert.insertId, image_url: thumbUrl, original_url: originalUrl });
    }

    res.status(201).json({ message: 'Images uploaded', images: results });
  } catch (e) { next(e); }
};

export const getRoomImages = async (req, res, next) => {
  try {
    const roomId = Number(req.params.id);
    if (!Number.isInteger(roomId) || roomId <= 0) {
      return res.status(400).json({ message: "room id must be a positive integer" });
    }

    let hotelId = await hotelIdByRoomId(roomId);
    if (!hotelId) {
      return res.status(404).json({ message: "Room not found" });
    }

    if (req.user?.role === "hotel_manager") {
      const owns = await managerOwnsHotel(req.user.id, hotelId);
      if (!owns) {
        return res.status(403).json({ message: "You are not allowed to manage this hotel" });
      }
    }

    const [rows] = await pool.query(
      `SELECT id, room_id, image_url, created_at
         FROM room_images
        WHERE room_id = ?
        ORDER BY id ASC`,
      [roomId],
    );

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};

// Liệt kê các khoảng ngày đã đặt (không tính CANCELLED)
export const listRoomBookedRanges = async (req, res, next) => {
  try {
    const roomId = Number(req.params.id);
    if (!Number.isInteger(roomId) || roomId <= 0) {
      return res.status(400).json({ message: "room id must be a positive integer" });
    }

    const [rows] = await pool.query(
      `SELECT DATE_FORMAT(check_in, '%Y-%m-%d') AS check_in,
              DATE_FORMAT(check_out, '%Y-%m-%d') AS check_out,
              status
         FROM bookings
        WHERE room_id = ?
          AND status IN ('pending','confirmed','completed')
        ORDER BY check_in ASC`,
      [roomId]
    );

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};

export const replaceRoomImage = async (req, res, next) => {
  try {
    const imageId = Number(req.params.imageId);
    if (!Number.isInteger(imageId) || imageId <= 0) {
      return res.status(400).json({ message: "image id must be a positive integer" });
    }
    const file = req.file;
    if (!file) return res.status(400).json({ message: "file is required" });

    const [[existing]] = await pool.query(
      `SELECT ri.id, ri.room_id, ri.image_url, r.hotel_id
         FROM room_images ri
         JOIN rooms r ON r.id = ri.room_id
        WHERE ri.id = ?
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

    ensureUploadDirs();

    const originalFilename = file.filename;
    const originalPath = path.join(ORIGINALS_DIR, originalFilename);
    const thumbFilename = `thumb-${originalFilename}`;
    const thumbPath = path.join(THUMBS_DIR, thumbFilename);

    await sharp(originalPath).resize(300, 200, { fit: "cover" }).toFile(thumbPath);
    const originalUrl = `/uploads/rooms/originals/${originalFilename}`;
    const thumbUrl = `/uploads/rooms/thumbs/${thumbFilename}`;

    await pool.query(
      "UPDATE room_images SET image_url = ? WHERE id = ?",
      [thumbUrl, imageId],
    );

    removeStoredImage(existing.image_url);

    res.json({
      message: "Image updated",
      image_url: thumbUrl,
      original_url: originalUrl,
    });
  } catch (err) {
    next(err);
  }
};

export const deleteRoomImage = async (req, res, next) => {
  try {
    const imageId = Number(req.params.imageId);
    if (!Number.isInteger(imageId) || imageId <= 0) {
      return res.status(400).json({ message: "image id must be a positive integer" });
    }

    const [[existing]] = await pool.query(
      `SELECT ri.id, ri.room_id, ri.image_url, r.hotel_id
         FROM room_images ri
         JOIN rooms r ON r.id = ri.room_id
        WHERE ri.id = ?
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

    await pool.query("DELETE FROM room_images WHERE id = ?", [imageId]);
    removeStoredImage(existing.image_url);

    res.json({ message: "Image removed" });
  } catch (err) {
    next(err);
  }
};

