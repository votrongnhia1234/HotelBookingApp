import bcrypt from "bcryptjs";
import pool from "../config/db.js";
import { signToken } from "../utils/token.js";

export const register = async (req, res, next) => {
  try {
    const { name, email, password, phone, address, role = "customer" } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: "Missing required fields" });

    const [exists] = await pool.query("SELECT id FROM users WHERE email = ? LIMIT 1", [email]);
    if (exists.length) return res.status(409).json({ message: "Email already taken" });

    // tìm role_id
    const [roleRows] = await pool.query("SELECT id FROM roles WHERE role_name = ? LIMIT 1", [role]);
    if (!roleRows.length) return res.status(400).json({ message: "Invalid role" });

    const hash = await bcrypt.hash(password, +process.env.BCRYPT_SALT_ROUNDS || 10);

    const [result] = await pool.query(
      `INSERT INTO users (role_id, name, email, password, phone, address)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [roleRows[0].id, name, email, hash, phone || null, address || null]
    );

    const token = signToken({ id: result.insertId });
    res.status(201).json({ token, user: { id: result.insertId, name, email, role } });
  } catch (e) { next(e); }
};

export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, u.password, r.role_name AS role
       FROM users u JOIN roles r ON r.id = u.role_id
       WHERE u.email = ? LIMIT 1`, [email]
    );
    if (!rows.length) return res.status(401).json({ message: "Invalid credentials" });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    const token = signToken({ id: user.id });
    delete user.password;
    res.json({ token, user });
  } catch (e) { next(e); }
};
