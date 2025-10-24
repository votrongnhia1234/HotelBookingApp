import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import pool from "../config/db.js";
import { signToken } from "../utils/token.js";
import nodemailer from 'nodemailer';

const CUSTOMER_ROLE = "customer";
const FALLBACK_PASSWORD = "firebase-auth-placeholder";

async function ensureCustomerRoleId() {
  const [rows] = await pool.query(
    "SELECT id FROM roles WHERE role_name = ? LIMIT 1",
    [CUSTOMER_ROLE]
  );
  if (rows.length) {
    return rows[0].id;
  }
  // Fallback: auto-create 'customer' role if missing to avoid blocking login
  const [insert] = await pool.query(
    "INSERT INTO roles (role_name) VALUES (?)",
    [CUSTOMER_ROLE]
  );
  return insert.insertId;
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

async function findUserByEmail(email) {
  const [rows] = await pool.query(
    `SELECT u.id, u.name, u.email, u.phone, r.role_name AS role
     FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE u.email = ?
     LIMIT 1`,
    [email]
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

export const loginByPhone = async (req, res, next) => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password) {
      return res.status(400).json({ message: "Phone and password are required" });
    }

    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, u.phone, u.password, r.role_name AS role
         FROM users u
         JOIN roles r ON r.id = u.role_id
        WHERE u.phone = ?
        LIMIT 1`,
      [phone],
    );

    if (!rows.length) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

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
    const name = payload.name || "Người dùng";
    const providerId = payload.sub || `firebase-${Date.now()}`;
    const email =
      payload.email ||
      `${providerId.replace(/[^a-zA-Z0-9]/g, "")}@firebase-user.stayeasy`;

    let user = null;

    // Prefer phone lookup when phone is present (phone auth flows)
    if (phone) {
      user = await findUserByPhone(phone);
    }

    // Fallback to email lookup when phone is not available (Google sign-in, etc.)
    if (!user) {
      user = await findUserByEmail(email);
    }

    if (!user) {
      const roleId = await ensureCustomerRoleId();
      const hash = await bcrypt.hash(
        `${FALLBACK_PASSWORD}-${providerId}`,
        +process.env.BCRYPT_SALT_ROUNDS || 10
      );

      const [insert] = await pool.query(
        `INSERT INTO users (role_id, name, email, password, phone, address)
         VALUES (?, ?, ?, ?, ?, NULL)`,
        [roleId, name, email, hash, phone || null]
      );

      user = { id: insert.insertId, name, email, phone: phone || null, role: CUSTOMER_ROLE };
    }

    const token = signToken({ id: user.id });

    // Send notification / verification email to real email if present
    try {
      // Only send if this is a real email (not the generated fallback)
      const fallbackSuffix = '@firebase-user.stayeasy';
      const recipient = user.email;
      if (recipient && !recipient.endsWith(fallbackSuffix)) {
        const transporter = nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : undefined,
          secure: process.env.SMTP_SECURE === 'true',
          auth: process.env.SMTP_USER
            ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
            : undefined,
        });

        const mailOptions = {
          from: process.env.SMTP_FROM || 'no-reply@stayeasy.example',
          to: recipient,
          subject: 'Thông báo đăng nhập mới vào StayEasy',
          text: `Chúng tôi nhận thấy một lần đăng nhập mới vào tài khoản StayEasy của bạn. Nếu bạn vừa đăng nhập, bạn có thể bỏ qua email này. Nếu không phải bạn, vui lòng đổi mật khẩu hoặc liên hệ với hỗ trợ.`,
          html: `<p>Chúng tôi nhận thấy một lần đăng nhập mới vào tài khoản <strong>StayEasy</strong> của bạn.</p>
                 <p>Nếu đây là bạn, bạn có thể bỏ qua email này.</p>
                 <p>Nếu bạn không thực hiện đăng nhập này, hãy đổi mật khẩu ngay lập tức hoặc liên hệ với bộ phận hỗ trợ.</p>`,
        };

        // send but don't block the response on failure
        transporter.sendMail(mailOptions).catch((err) => {
          // log error server-side; do not fail login
          console.error('Failed to send login notification email', err);
        });
      }
    } catch (mailErr) {
      console.error('Error preparing login notification email', mailErr);
    }

    res.json({ token, user });
  } catch (e) {
    next(e);
  }
};
