import jwt from "jsonwebtoken";
import pool from "../config/db.js";

/** Bắt buộc có token */
export const protect = async (req, res, next) => {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.split(" ")[1] : null;
    if (!token) return res.status(401).json({ message: "Unauthorized" });

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Lấy user từ DB (kèm role)
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, r.role_name AS role
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.id = ? LIMIT 1`, [decoded.id]
    );

    if (!rows[0]) return res.status(401).json({ message: "User not found" });

    req.user = rows[0];
    next();
  } catch (e) {
    return res.status(401).json({ message: "Invalid token" });
  }
};

/** Chỉ cho phép 1 trong các role */
export const authorize = (...allowedRoles) => (req, res, next) => {
  if (!req.user) return res.status(401).json({ message: "Unauthorized" });
  if (!allowedRoles.includes(req.user.role))
    return res.status(403).json({ message: "Forbidden" });
  next();
};
