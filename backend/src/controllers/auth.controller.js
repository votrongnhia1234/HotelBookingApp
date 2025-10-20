import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import pool from "../config/db.js";
import { signToken } from "../utils/token.js";

const CUSTOMER_ROLE = "customer";
const FALLBACK_PASSWORD = "firebase-auth-placeholder";

async function ensureCustomerRoleId() {
  const [rows] = await pool.query(
    "SELECT id FROM roles WHERE role_name = ? LIMIT 1",
    [CUSTOMER_ROLE]
  );
  if (!rows.length) {
    throw new Error(`Role "${CUSTOMER_ROLE}" is not configured in database`);
  }
  return rows[0].id;
}

async function findUserByPhone(phone) {
  const [rows] = await pool.query(
    `SELECT u.id, u.name, u.email, u.phone, r.role_name AS role
     FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE u.phone = ?
     LIMIT 1`,
    [phone]
  );
  return rows.length ? rows[0] : null;
}

export const register = async (req, res, next) => {
  try {
    const { name, email, password, phone, address, role = CUSTOMER_ROLE } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    const [exists] = await pool.query("SELECT id FROM users WHERE email = ? LIMIT 1", [email]);
    if (exists.length) return res.status(409).json({ message: "Email already taken" });

    const roleId = await ensureCustomerRoleId();
    const hash = await bcrypt.hash(password, +process.env.BCRYPT_SALT_ROUNDS || 10);

    const [result] = await pool.query(
      `INSERT INTO users (role_id, name, email, password, phone, address)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [roleId, name, email, hash, phone || null, address || null]
    );

    const token = signToken({ id: result.insertId });
    res.status(201).json({ token, user: { id: result.insertId, name, email, role } });
  } catch (e) {
    next(e);
  }
};

export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, u.password, r.role_name AS role
       FROM users u JOIN roles r ON r.id = u.role_id
       WHERE u.email = ? LIMIT 1`,
      [email]
    );
    if (!rows.length) return res.status(401).json({ message: "Invalid credentials" });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    const token = signToken({ id: user.id });
    delete user.password;
    res.json({ token, user });
  } catch (e) {
    next(e);
  }
};

export const loginWithFirebase = async (req, res, next) => {
  try {
    const { idToken } = req.body;
    if (!idToken) return res.status(400).json({ message: "Missing idToken" });

    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded?.payload) return res.status(401).json({ message: "Invalid token" });

    const payload = decoded.payload;
    const phone = payload.phone_number || payload.phone;
    if (!phone) return res.status(400).json({ message: "Firebase token lacks phone_number" });

    const name = payload.name || "Người dùng";
    const providerId = payload.sub || `firebase-${phone}`;
    const email =
      payload.email ||
      `${providerId.replace(/[^a-zA-Z0-9]/g, "")}@firebase-user.stayeasy`;

    let user = await findUserByPhone(phone);

    if (!user) {
      const roleId = await ensureCustomerRoleId();
      const hash = await bcrypt.hash(
        `${FALLBACK_PASSWORD}-${providerId}`,
        +process.env.BCRYPT_SALT_ROUNDS || 10
      );

      const [insert] = await pool.query(
        `INSERT INTO users (role_id, name, email, password, phone, address)
         VALUES (?, ?, ?, ?, ?, NULL)`,
        [roleId, name, email, hash, phone]
      );

      user = { id: insert.insertId, name, email, phone, role: CUSTOMER_ROLE };
    }

    const token = signToken({ id: user.id });
    res.json({ token, user });
  } catch (e) {
    next(e);
  }
};
