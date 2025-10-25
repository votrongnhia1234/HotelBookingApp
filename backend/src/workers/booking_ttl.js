import pool from "../config/db.js";

const DEFAULT_TTL_MINUTES = 15;
const RUN_INTERVAL_MS = 60 * 1000; // every minute

export const startBookingTtlWorker = () => {
  const ttlMinutes = Number(process.env.BOOKING_PENDING_TTL_MINUTES || DEFAULT_TTL_MINUTES);
  if (!Number.isFinite(ttlMinutes) || ttlMinutes <= 0) {
    console.warn("[TTL] BOOKING_PENDING_TTL_MINUTES không hợp lệ, bỏ qua worker");
    return;
  }

  const run = async () => {
    const conn = await pool.getConnection();
    try {
      const [[lock]] = await conn.query("SELECT GET_LOCK('booking_ttl_worker', 0) AS got");
      if (lock.got !== 1) {
        return; // another instance is running
      }

      try {
        const [result] = await conn.query(
          "UPDATE bookings SET status='cancelled' WHERE status='pending' AND created_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)",
          [ttlMinutes]
        );
        if (result.affectedRows) {
          console.log(`[TTL] Đã tự hủy ${result.affectedRows} đơn pending quá ${ttlMinutes} phút`);
        }
      } finally {
        await conn.query("SELECT RELEASE_LOCK('booking_ttl_worker')");
      }
    } catch (err) {
      console.error("[TTL] Lỗi worker:", err.message || err);
    } finally {
      conn.release();
    }
  };

  // first run after startup delay to avoid heavy load
  setTimeout(run, 10 * 1000);
  setInterval(run, RUN_INTERVAL_MS);

  console.log(`[TTL] Booking TTL worker khởi động với TTL=${ttlMinutes} phút`);
};