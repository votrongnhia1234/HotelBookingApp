// src/routes/ai.routes.js
import express from "express";
import { GoogleGenerativeAI } from "@google/generative-ai";
import pool from "../config/db.js";
import { attachUserIfPresent } from "../middleware/auth.js";

const router = express.Router();

function createClient() {
  const key = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  console.log('[AI] GEMINI_API_KEY length=', (key || '').length);
  if (!key || !key.trim()) {
    throw Object.assign(new Error("GEMINI_API_KEY chưa được cấu hình"), {
      statusCode: 503,
      code: "AI_NOT_CONFIGURED",
    });
  }
  return new GoogleGenerativeAI(key);
}

// Model selection with fallback via env
function selectModelIds() {
  const primary = (process.env.GEMINI_MODEL || 'gemini-flash-latest').trim();
  const fallbackEnv = (process.env.GEMINI_FALLBACK_MODEL || 'gemini-1.5-flash').trim();
  const fallback = fallbackEnv && fallbackEnv !== primary ? fallbackEnv : null;
  return { primary, fallback };
}

function isOverloadedError(err) {
  const msg = String(err?.message || '');
  const status = Number(err?.status || err?.statusCode || 0);
  return status === 503 || msg.toLowerCase().includes('service unavailable') || msg.toLowerCase().includes('overloaded');
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function sendWithRetry(chat, text, { attempts = 3, delays = [400, 800, 1600] } = {}) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      const result = await chat.sendMessage(String(text ?? ''));
      return result;
    } catch (err) {
      lastErr = err;
      // Only retry on transient errors (503/network)
      if (!isOverloadedError(err)) break;
      const delay = delays[Math.min(i, delays.length - 1)] || 500;
      await sleep(delay);
    }
  }
  throw lastErr;
}

// Helper: format VND
function formatVnd(n) {
  const num = Number(n);
  if (!Number.isFinite(num) || num <= 0) return "";
  return new Intl.NumberFormat('vi-VN').format(Math.round(num));
}

// Helper: fetch featured hotels (top by rating, optional city filter)
async function fetchFeaturedHotels({ city, limit = 5 } = {}) {
  const lim = Number(limit) && Number(limit) > 0 ? Number(limit) : 5;
  const [rows] = await pool.query(
    `SELECT h.id, h.name, h.city, h.rating, COALESCE(MIN(r.price_per_night), 0) AS min_price
     FROM hotels h
     LEFT JOIN rooms r ON r.hotel_id = h.id
     WHERE (? IS NULL OR h.city = ?)
     GROUP BY h.id
     ORDER BY h.rating DESC, min_price ASC
     LIMIT ?`,
    [city ?? null, city ?? null, lim]
  );
  return rows;
}

function buildFeaturedHotelsContext(rows, city) {
  if (!rows || !rows.length) {
    return `Hiện chưa có dữ liệu khách sạn nổi bật${city ? ` tại ${city}` : ''}.`;
  }
  const list = rows.map((h, i) => {
    const price = h.min_price ? `${formatVnd(h.min_price)}đ/đêm` : 'Giá không có sẵn';
    const rating = (h.rating != null && h.rating !== '') ? Number(h.rating).toFixed(1) : 'N/A';
    return `${i + 1}. ${h.name} — ${h.city} • Rating ${rating} • Từ ${price}`;
  });
  return list.join('\n');
}

// ===== User bookings context =====
async function fetchUserBookings(userId, { limit = 10 } = {}) {
  const lim = Number(limit) && Number(limit) > 0 ? Number(limit) : 10;
  const [rows] = await pool.query(
    `SELECT b.id,
            DATE_FORMAT(b.check_in, '%Y-%m-%d') AS check_in,
            DATE_FORMAT(b.check_out, '%Y-%m-%d') AS check_out,
            b.total_price,
            b.status,
            GREATEST(DATEDIFF(b.check_out, b.check_in), 1) AS nights,
            r.room_number,
            r.type AS room_type,
            r.price_per_night,
            h.name AS hotel_name,
            h.city
       FROM bookings b
       JOIN rooms r ON r.id = b.room_id
       JOIN hotels h ON h.id = r.hotel_id
      WHERE b.user_id = ?
      ORDER BY b.created_at DESC
      LIMIT ?`,
    [userId, lim]
  );
  return rows;
}

function buildUserBookingsContext(rows) {
  if (!rows || !rows.length) {
    return 'Bạn chưa có đặt phòng nào gần đây.';
  }
  const list = rows.map((b, i) => {
    const total = b.total_price ? `${formatVnd(b.total_price)}đ` : 'N/A';
    const pn = b.price_per_night ? `${formatVnd(b.price_per_night)}đ/đêm` : 'N/A';
    return `${i + 1}. ${b.hotel_name} — ${b.city} • Phòng ${b.room_type} #${b.room_number} • ${b.check_in} → ${b.check_out} (${b.nights} đêm) • Trạng thái: ${b.status} • Tổng: ${total} • Giá/đêm: ${pn}`;
  });
  return list.join('\n');
}

// ===== Available rooms context =====
async function fetchAvailableRooms({ checkIn, checkOut, hotelId, city, limit = 8 } = {}) {
  const lim = Number(limit) && Number(limit) > 0 ? Number(limit) : 8;
  if (!checkIn || !checkOut) return [];
  const params = [checkOut, checkIn];
  let hotelFilter = "";
  let cityFilter = "";
  if (hotelId) { hotelFilter = "AND r.hotel_id = ?"; params.push(hotelId); }
  if (city) { cityFilter = "AND h.city = ?"; params.push(city); }
  const sql = `
      SELECT r.id, r.hotel_id, r.room_number, r.type, r.price_per_night, r.status,
             h.name AS hotel_name, h.city
      FROM rooms r
      JOIN hotels h ON h.id = r.hotel_id
      LEFT JOIN bookings b
        ON b.room_id = r.id
       AND b.status IN ('pending','confirmed','completed')
       AND (? > b.check_in AND ? < b.check_out)
      WHERE r.status <> 'maintenance'
        ${hotelFilter}
        ${cityFilter}
        AND b.id IS NULL
      ORDER BY r.price_per_night ASC
      LIMIT ${lim}
    `;
  const [rows] = await pool.query(sql, params);
  return rows;
}

function buildAvailableRoomsContext(rows, { checkIn, checkOut, city, hotelId }) {
  if (!rows || !rows.length) {
    const scope = city ? ` tại ${city}` : (hotelId ? ` trong khách sạn #${hotelId}` : '');
    return `Chưa tìm thấy phòng trống${scope} cho khoảng ${checkIn} → ${checkOut}.`;
  }
  const list = rows.map((r, i) => {
    const price = r.price_per_night ? `${formatVnd(r.price_per_night)}đ/đêm` : 'N/A';
    return `${i + 1}. ${r.hotel_name} — ${r.city} • Phòng ${r.type} #${r.room_number} • ${price} • Trạng thái: ${r.status}`;
  });
  return list.join('\n');
}

// Simple Chat endpoint (non-streaming) using Gemini
router.post("/chat", attachUserIfPresent, async (req, res, next) => {
  try {
    const { message, messages, contextType, city, limit, checkIn, checkOut, hotelId } = req.body || {};

    // Build conversation messages
    const convo = Array.isArray(messages) ? messages : [];
    if (message && (!convo.length || convo[convo.length - 1]?.role !== "user")) {
      convo.push({ role: "user", content: String(message) });
    }

    const genAI = createClient();

    const baseInstruction =
      "Bạn là StayEasy Assistant: trợ lý du lịch và đặt phòng khách sạn. Trả lời ngắn gọn, hữu ích, và lịch sự bằng tiếng Việt. Khi người dùng muốn đặt phòng, hỏi ngày nhận/trả phòng, số khách và ngân sách. Nếu cần, gợi ý khách sạn nổi bật của StayEasy.";

    let systemInstruction = baseInstruction;
    const ctx = (contextType ?? 'featured_hotels');
    if (ctx === 'featured_hotels') {
      try {
        const rows = await fetchFeaturedHotels({ city, limit });
        const ctxText = buildFeaturedHotelsContext(rows, city);
        systemInstruction = `${baseInstruction}\n\nDữ liệu tham chiếu (khách sạn nổi bật${city ? ` tại ${city}` : ''}):\n${ctxText}\n\nKhi sử dụng dữ liệu, nêu rõ đây là gợi ý tham khảo từ hệ thống, không đảm bảo còn phòng trống.`;
      } catch (e) {
        console.warn('[AI] Lỗi lấy featured hotels', e);
      }
    } else if (ctx === 'user_bookings') {
      if (req.user?.id) {
        try {
          const rows = await fetchUserBookings(req.user.id, { limit });
          const ctxText = buildUserBookingsContext(rows);
          systemInstruction = `${baseInstruction}\n\nDữ liệu tham chiếu (đặt phòng của người dùng hiện tại):\n${ctxText}\n\nKhi sử dụng dữ liệu, nêu rõ đây là thông tin đơn đặt phòng của người dùng hiện tại, có thể thay đổi theo thời gian.`;
        } catch (e) {
          console.warn('[AI] Lỗi lấy user bookings', e);
        }
      } else {
        systemInstruction = `${baseInstruction}\n\nLưu ý: Người dùng chưa xác thực, không thể lấy danh sách đặt phòng. Hãy hướng dẫn người dùng đăng nhập để xem lịch sử đặt phòng.`;
      }
    } else if (ctx === 'available_rooms') {
      if (checkIn && checkOut) {
        try {
          const rows = await fetchAvailableRooms({ checkIn, checkOut, hotelId, city, limit });
          const ctxText = buildAvailableRoomsContext(rows, { checkIn, checkOut, city, hotelId });
          const scope = city ? ` tại ${city}` : (hotelId ? ` của khách sạn #${hotelId}` : '');
          systemInstruction = `${baseInstruction}\n\nDữ liệu tham chiếu (phòng trống${scope} trong khoảng ${checkIn} → ${checkOut}):\n${ctxText}\n\nLưu ý: Tình trạng phòng có thể thay đổi, cần xác nhận lại khi đặt.`;
        } catch (e) {
          console.warn('[AI] Lỗi lấy available rooms', e);
        }
      } else {
        systemInstruction = `${baseInstruction}\n\nLưu ý: Thiếu tham số checkIn/checkOut để tra cứu phòng trống.`;
      }
    }

    const { primary, fallback } = selectModelIds();
    const buildModel = (modelId) => genAI.getGenerativeModel({
      model: modelId,
      systemInstruction,
      generationConfig: { temperature: 0.7 },
    });

    // Map history to Gemini format
    const history = convo.map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: String(m.content ?? "") }],
    }));

    // Try primary model with retry/backoff
    let text;
    try {
      const chatPrimary = buildModel(primary).startChat({ history });
      const result = await sendWithRetry(chatPrimary, String(message ?? ""));
      text = result.response.text();
    } catch (err) {
      if (fallback && isOverloadedError(err)) {
        // Fallback to secondary model
        try {
          const chatFallback = buildModel(fallback).startChat({ history });
          const resultFb = await sendWithRetry(chatFallback, String(message ?? ""), { attempts: 2, delays: [600, 1200] });
          text = resultFb.response.text();
        } catch (errFb) {
          // Re-throw original if fallback also fails
          throw errFb;
        }
      } else {
        throw err;
      }
    }

    return res.status(200).json({
      role: "assistant",
      content: text.trim(),
      // usage not available the same way as OpenAI; omit or fill later
    });
  } catch (err) {
    // Normalize common provider error codes for client
    const msg = String(err?.message || "Lỗi AI không xác định");
    if (msg.includes("quota") || msg.includes("insufficient")) {
      err.statusCode = err.statusCode || 429;
      err.code = err.code || "INSUFFICIENT_QUOTA";
    }
    if (isOverloadedError(err)) {
      err.statusCode = err.statusCode || 503;
      err.code = err.code || "AI_PROVIDER_UNAVAILABLE";
      err.message = "Dịch vụ AI đang quá tải, vui lòng thử lại sau.";
    }
    next(err);
  }
});

export default router;
