/**
 * Seed room_images from existing files in uploads/rooms.
 *
 * Usage examples:
 *  - node scripts/seed-room-images.js --room-id=1            // attach all originals to room 1
 *  - node scripts/seed-room-images.js --room-id=1 --dry-run  // print intended actions only
 *
 * Requirements:
 *  - Place original images in: uploads/rooms/originals
 *  - Thumbnails will be generated in: uploads/rooms/thumbs
 *  - DB connection uses env: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
 */

import fs from "fs";
import path from "path";
import sharp from "sharp";
import dotenv from "dotenv";
import pool from "../src/config/db.js";

dotenv.config();

const ROOT = process.cwd();
const ORIGINALS_DIR = path.join(ROOT, "uploads", "rooms", "originals");
const THUMBS_DIR = path.join(ROOT, "uploads", "rooms", "thumbs");

function parseArgs() {
  const args = Object.fromEntries(
    process.argv.slice(2).map((arg) => {
      const m = arg.match(/^--([^=]+)(=(.*))?$/);
      if (!m) return [arg.replace(/^--/, ""), true];
      return [m[1], m[3] ?? true];
    })
  );
  return {
    roomId: args["room-id"] ? Number(args["room-id"]) : null,
    dryRun: !!args["dry-run"],
  };
}

function ensureDirs() {
  fs.mkdirSync(ORIGINALS_DIR, { recursive: true });
  fs.mkdirSync(THUMBS_DIR, { recursive: true });
}

async function ensureThumbFor(filename) {
  const originalPath = path.join(ORIGINALS_DIR, filename);
  const thumbFilename = `thumb-${filename}`;
  const thumbPath = path.join(THUMBS_DIR, thumbFilename);

  if (!fs.existsSync(originalPath)) {
    throw new Error(`Original not found: ${originalPath}`);
  }
  if (!fs.existsSync(thumbPath)) {
    await sharp(originalPath).resize(300, 200, { fit: "cover" }).toFile(thumbPath);
    console.log(`Created thumb: ${thumbPath}`);
  }
  return thumbFilename;
}

async function imageExists(roomId, imageUrl) {
  const [rows] = await pool.query(
    `SELECT id FROM room_images WHERE room_id = ? AND image_url = ? LIMIT 1`,
    [roomId, imageUrl]
  );
  return rows.length > 0;
}

async function insertImage(roomId, imageUrl) {
  const [result] = await pool.query(
    `INSERT INTO room_images (room_id, image_url) VALUES (?, ?)`,
    [roomId, imageUrl]
  );
  return result.insertId;
}

async function main() {
  const { roomId, dryRun } = parseArgs();
  if (!roomId || !Number.isInteger(roomId) || roomId <= 0) {
    console.error("--room-id is required and must be a positive integer");
    process.exit(1);
  }

  ensureDirs();

  const files = fs.readdirSync(ORIGINALS_DIR).filter((f) => {
    const ext = path.extname(f).toLowerCase();
    return [".jpg", ".jpeg", ".png", ".webp"].includes(ext);
  });
  if (!files.length) {
    console.log(`No original images found in ${ORIGINALS_DIR}`);
    process.exit(0);
  }

  console.log(`Seeding ${files.length} images to room_id=${roomId}`);

  for (const file of files) {
    try {
      const thumbFilename = await ensureThumbFor(file);
      const url = `/uploads/rooms/thumbs/${thumbFilename}`;

      const exists = await imageExists(roomId, url);
      if (exists) {
        console.log(`Skip existing DB row for room_id=${roomId} url=${url}`);
        continue;
      }

      if (dryRun) {
        console.log(`[DRY RUN] Would insert: room_id=${roomId}, image_url=${url}`);
      } else {
        const id = await insertImage(roomId, url);
        console.log(`Inserted room_images id=${id} room_id=${roomId} url=${url}`);
      }
    } catch (err) {
      console.error(`Failed processing ${file}:`, err.message || err);
    }
  }

  await pool.end();
  console.log("Done.");
}

main().catch(async (err) => {
  console.error(err);
  try { await pool.end(); } catch (_) {}
  process.exit(1);
});