import pool from "../config/db.js";

export const createPayment = async (req, res, next) => {
  try {
    const { booking_id, amount, method } = req.body;
    if (!booking_id || amount == null || !method) {
      return res.status(400).json({ message: "booking_id, amount, method required" });
    }

    const [rows] = await pool.query(
      "SELECT id, status FROM bookings WHERE id = ? LIMIT 1",
      [booking_id]
    );
    if (!rows.length) return res.status(404).json({ message: "Booking not found" });

    const nextStatus = method === "online" ? "completed" : "confirmed";
    await pool.query("UPDATE bookings SET status = ? WHERE id = ?", [nextStatus, booking_id]);

    res.status(201).json({
      data: {
        booking_id,
        amount: Number(amount),
        method,
        status: nextStatus,
      },
    });
  } catch (e) {
    next(e);
  }
};
