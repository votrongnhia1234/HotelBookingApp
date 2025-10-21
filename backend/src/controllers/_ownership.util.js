import pool from "../config/db.js";

/** manager có sở hữu hotel_id này không? */
export const managerOwnsHotel = async (managerUserId, hotelId) => {
  const [rows] = await pool.query(
    "SELECT 1 FROM hotel_managers WHERE user_id=? AND hotel_id=? LIMIT 1",
    [managerUserId, hotelId]
  );
  return rows.length > 0;
};

/** lấy hotel_id từ room_id */
export const hotelIdByRoomId = async (roomId) => {
  const [rows] = await pool.query(
    "SELECT hotel_id FROM rooms WHERE id=? LIMIT 1",
    [roomId]
  );
  return rows[0]?.hotel_id ?? null;
};

/** lấy hotel_id từ booking_id (join qua room) */
export const hotelIdByBookingId = async (bookingId) => {
  const [rows] = await pool.query(
    `SELECT r.hotel_id
       FROM bookings b JOIN rooms r ON r.id=b.room_id
      WHERE b.id=? LIMIT 1`,
    [bookingId]
  );
  return rows[0]?.hotel_id ?? null;
};

export const hotelIdByVoucherId = async (voucherId) => {
  const [rows] = await pool.query(
    "SELECT hotel_id FROM vouchers WHERE id=? LIMIT 1",
    [voucherId]
  );
  return rows[0]?.hotel_id ?? null;
};
