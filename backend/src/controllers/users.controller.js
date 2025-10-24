import pool from "../config/db.js";

export const getCurrentProfile = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, name, email, phone, address
         FROM users
        WHERE id = ?
        LIMIT 1`,
      [req.user.id],
    );

    if (!rows.length) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ data: rows[0] });
  } catch (err) {
    next(err);
  }
};

export const updateCurrentProfile = async (req, res, next) => {
  try {
    const { name, phone, address } = req.body ?? {};
    const fields = [];
    const values = [];

    if (typeof name === "string" && name.trim().length) {
      fields.push("name = ?");
      values.push(name.trim());
    }
    if (typeof phone === "string" && phone.trim().length) {
      fields.push("phone = ?");
      values.push(phone.trim());
    }
    if (typeof address === "string") {
      fields.push("address = ?");
      values.push(address.trim());
    }

    if (fields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(req.user.id);

    await pool.query(
      `UPDATE users
          SET ${fields.join(", ")}
        WHERE id = ?`,
      values,
    );

    const [rows] = await pool.query(
      `SELECT id, name, email, phone, address
         FROM users
        WHERE id = ?
        LIMIT 1`,
      [req.user.id],
    );

    res.json({ data: rows[0] });
  } catch (err) {
    if (err?.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Phone number already in use" });
    }
    next(err);
  }
};

export const getCurrentTransactions = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT b.id,
              b.room_id,
              b.check_in,
              b.check_out,
              b.total_price,
              b.status,
              b.created_at,
              r.room_number,
              r.type AS room_type,
              h.id AS hotel_id,
              h.name AS hotel_name
         FROM bookings b
         JOIN rooms r ON r.id = b.room_id
         JOIN hotels h ON h.id = r.hotel_id
        WHERE b.user_id = ?
        ORDER BY b.created_at DESC`,
      [req.user.id],
    );

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
};
