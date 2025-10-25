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
      return res.status(404).json({ message: "User not found", code: "NOT_FOUND" });
    }

    res.json({ data: rows[0] });
  } catch (err) {
    next(err);
  }
};

export const updateCurrentProfile = async (req, res, next) => {
  try {
    const { name, phone, address, email } = req.body ?? {};
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
    if (typeof email === "string" && email.trim().length) {
      const normalized = email.trim();
      const fallbackSuffix = "@firebase-user.stayeasy";
      if (normalized.endsWith(fallbackSuffix)) {
        return res.status(400).json({ message: "Email không hợp lệ", code: "INVALID_EMAIL" });
      }
      const [[dupe]] = await pool.query(
        "SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1",
        [normalized, req.user.id]
      );
      if (dupe) {
        return res.status(409).json({ message: "Email đã được sử dụng", code: "EMAIL_IN_USE" });
      }
      fields.push("email = ?");
      values.push(normalized);
    }

    if (fields.length === 0) {
      return res.status(400).json({ message: "No fields to update", code: "NO_FIELDS_TO_UPDATE" });
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
      const msg = String(err.message || "").includes("phone") ? "Phone number already in use" : "Duplicate value";
      const code = String(err.message || "").includes("phone") ? "PHONE_IN_USE" : "DUPLICATE_VALUE";
      return res.status(409).json({ message: msg, code });
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
              h.name AS hotel_name,
              (SELECT ri.image_url FROM room_images ri WHERE ri.room_id = r.id ORDER BY ri.id ASC LIMIT 1) AS image_url
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
