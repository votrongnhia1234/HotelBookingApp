import pool from "../config/db.js";
import bcrypt from "bcrypt";

/* ========= Helpers ========= */
const parseIntOr = (v, d) => Number.isFinite(Number(v)) ? Number(v) : d;
const todayISO = () => new Date(Date.now() - new Date().getTimezoneOffset()*60000).toISOString().slice(0,10);

/* ========= Users Management ========= */

// GET /admin/users?q=&role=&page=&limit=
export const listUsers = async (req, res, next) => {
  try {
    const { q, role, page = 1, limit = 20 } = req.query;
    const offset = (parseIntOr(page,1)-1) * parseIntOr(limit,20);

    const filters = [];
    const params = [];

    if (q) { filters.push("(u.name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)"); params.push(`%${q}%`,`%${q}%`,`%${q}%`); }
    if (role) { filters.push("r.role_name = ?"); params.push(role); }

    const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, u.phone, u.address, u.created_at, u.updated_at, r.role_name as role
         FROM users u JOIN roles r ON r.id = u.role_id
        ${where}
        ORDER BY u.created_at DESC
        LIMIT ? OFFSET ?`, [...params, parseIntOr(limit,20), offset]
    );
    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) AS total FROM users u JOIN roles r ON r.id=u.role_id ${where}`, params
    );
    res.json({ data: rows, total, page: parseIntOr(page,1), limit: parseIntOr(limit,20) });
  } catch (e) { next(e); }
};

// GET /admin/users/:id
export const getUser = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.email, u.phone, u.address, u.created_at, u.updated_at, r.role_name as role
         FROM users u JOIN roles r ON r.id = u.role_id WHERE u.id=? LIMIT 1`, [id]
    );
    if (!rows.length) return res.status(404).json({ message: "User not found" });
    res.json(rows[0]);
  } catch (e) { next(e); }
};

// POST /admin/users  { name,email,password,role,phone,address }
export const createUser = async (req, res, next) => {
  try {
    const { name, email, password, role="customer", phone, address } = req.body;
    if (!name || !email || !password) return res.status(400).json({ message: "name, email, password required" });

    const [[dupe]] = await pool.query(`SELECT id FROM users WHERE email=? LIMIT 1`, [email]);
    if (dupe) return res.status(409).json({ message: "Email already exists" });

    const [[roleRow]] = await pool.query(`SELECT id FROM roles WHERE role_name=? LIMIT 1`, [role]);
    if (!roleRow) return res.status(400).json({ message: "Invalid role" });

    const hash = await bcrypt.hash(password, +process.env.BCRYPT_SALT_ROUNDS || 10);
    const [r] = await pool.query(
      `INSERT INTO users (role_id, name, email, password, phone, address)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [roleRow.id, name, email, hash, phone || null, address || null]
    );
    res.status(201).json({ id: r.insertId, name, email, role, phone, address });
  } catch (e) { next(e); }
};

// PATCH /admin/users/:id  { name?, phone?, address? }
export const updateUser = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const fields = [];
    const params = [];

    ["name","phone","address"].forEach(k=>{
      if (req.body[k] !== undefined) { fields.push(`${k}=?`); params.push(req.body[k]); }
    });
    if (!fields.length) return res.status(400).json({ message: "No fields to update" });

    params.push(id);
    const [r] = await pool.query(`UPDATE users SET ${fields.join(",")} WHERE id=?`, params);
    if (r.affectedRows === 0) return res.status(404).json({ message: "User not found" });
    res.json({ message: "User updated" });
  } catch (e) { next(e); }
};

// PATCH /admin/users/:id/role  { role }
export const changeUserRole = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { role } = req.body;
    if (!role) return res.status(400).json({ message: "role required" });
    const [[roleRow]] = await pool.query(`SELECT id FROM roles WHERE role_name=? LIMIT 1`, [role]);
    if (!roleRow) return res.status(400).json({ message: "Invalid role" });

    const [r] = await pool.query(`UPDATE users SET role_id=? WHERE id=?`, [roleRow.id, id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "User not found" });
    res.json({ message: "Role updated", role });
  } catch (e) { next(e); }
};

// PATCH /admin/users/:id/deactivate  (soft lock user bằng đặt password null hoặc flag)
export const deactivateUser = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    // Cách đơn giản: đặt password = NULL để chặn login (hoặc thêm cột is_active TINYINT(1))
    const [r] = await pool.query(`UPDATE users SET password=NULL WHERE id=?`, [id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "User not found" });
    res.json({ message: "User deactivated" });
  } catch (e) { next(e); }
};

// DELETE /admin/users/:id (xóa cứng)
export const deleteUser = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [r] = await pool.query(`DELETE FROM users WHERE id=?`, [id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "User not found" });
    res.json({ message: "User deleted" });
  } catch (e) { next(e); }
};

/* ========= Dashboard & Analytics ========= */

// GET /admin/stats/dashboard
export const getDashboardStats = async (_req, res, next) => {
  try {
    const today = todayISO();
    const [[{ users }]] = await pool.query(`SELECT COUNT(*) users FROM users`);
    const [[{ hotels }]] = await pool.query(`SELECT COUNT(*) hotels FROM hotels`);
    const [[{ rooms }]] = await pool.query(`SELECT COUNT(*) rooms FROM rooms`);
    const [[{ bookings }]] = await pool.query(`SELECT COUNT(*) bookings FROM bookings`);
    const [[{ revenueAll }]] = await pool.query(
      `SELECT COALESCE(SUM(CASE WHEN status='completed' THEN amount END),0) revenueAll FROM payments`
    );
    const [[{ revenueToday }]] = await pool.query(
      `SELECT COALESCE(SUM(p.amount),0) revenueToday
         FROM payments p JOIN bookings b ON b.id=p.booking_id
        WHERE p.status='completed' AND DATE(b.updated_at)=?`, [today]
    );
    res.json({ users, hotels, rooms, bookings, revenueAll: Number(revenueAll)||0, revenueToday: Number(revenueToday)||0, asOf: today });
  } catch (e) { next(e); }
};

// GET /admin/stats/revenue?from=YYYY-MM-DD&to=YYYY-MM-DD&group=day|month
export const revenueByDate = async (req, res, next) => {
  try {
    const { from, to, group = "day" } = req.query;
    const grp = group === "month" ? "DATE_FORMAT(b.check_out,'%Y-%m')" : "DATE(b.check_out)";
    const params = [];
    let where = `WHERE p.status='completed'`;
    if (from) { where += ` AND b.check_out >= ?`; params.push(from); }
    if (to)   { where += ` AND b.check_out < DATE_ADD(?, INTERVAL 1 DAY)`; params.push(to); }

    const [rows] = await pool.query(
      `SELECT ${grp} as period, SUM(p.amount) revenue
         FROM payments p
         JOIN bookings b ON b.id=p.booking_id
        ${where}
        GROUP BY period
        ORDER BY period ASC`, params
    );
    res.json({ data: rows });
  } catch (e) { next(e); }
};

// GET /admin/stats/occupancy?date=YYYY-MM-DD
export const occupancyByHotel = async (req, res, next) => {
  try {
    const date = req.query.date || todayISO();
    // occupancy = số phòng đang được chiếm (bởi booking active tại ngày đó) / tổng phòng
    const [rows] = await pool.query(
      `SELECT h.id AS hotel_id, h.name,
              COUNT(DISTINCT r.id) AS total_rooms,
              COUNT(DISTINCT CASE WHEN b.id IS NOT NULL THEN r.id END) AS occupied_rooms,
              ROUND(100 * COUNT(DISTINCT CASE WHEN b.id IS NOT NULL THEN r.id END) / NULLIF(COUNT(DISTINCT r.id),0), 2) AS occupancy_rate
         FROM hotels h
         JOIN rooms r ON r.hotel_id = h.id
         LEFT JOIN bookings b
           ON b.room_id = r.id
          AND b.status IN ('pending','confirmed','completed')
          AND (? >= b.check_in AND ? < b.check_out)
        GROUP BY h.id, h.name
        ORDER BY occupancy_rate DESC, total_rooms DESC`,
      [date, date]
    );
    res.json({ date, data: rows });
  } catch (e) { next(e); }
};

// GET /admin/stats/top-hotels?from=&to=&limit=5
export const topHotels = async (req, res, next) => {
  try {
    const { from, to, limit = 5 } = req.query;
    const params = [];
    let where = `WHERE p.status='completed'`;
    if (from) { where += ` AND b.check_out >= ?`; params.push(from); }
    if (to)   { where += ` AND b.check_out < DATE_ADD(?, INTERVAL 1 DAY)`; params.push(to); }

    const [rows] = await pool.query(
      `SELECT h.id AS hotel_id, h.name, SUM(p.amount) AS revenue, COUNT(DISTINCT b.id) AS bookings
         FROM payments p
         JOIN bookings b ON b.id=p.booking_id
         JOIN rooms r ON r.id=b.room_id
         JOIN hotels h ON h.id=r.hotel_id
        ${where}
        GROUP BY h.id, h.name
        ORDER BY revenue DESC
        LIMIT ?`, [...params, parseIntOr(limit,5)]
    );
    res.json({ data: rows });
  } catch (e) { next(e); }
};

// GET /admin/stats/users-growth?from=&to=&group=month
export const usersGrowth = async (req, res, next) => {
  try {
    const { from, to, group = "month" } = req.query;
    const grp = group === "day" ? "DATE(created_at)" : "DATE_FORMAT(created_at,'%Y-%m')";
    const params = [];
    let where = `WHERE 1=1`;
    if (from) { where += ` AND created_at >= ?`; params.push(from); }
    if (to)   { where += ` AND created_at < DATE_ADD(?, INTERVAL 1 DAY)`; params.push(to); }

    const [rows] = await pool.query(
      `SELECT ${grp} AS period, COUNT(*) as new_users
         FROM users
        ${where}
        GROUP BY period
        ORDER BY period ASC`, params
    );
    res.json({ data: rows });
  } catch (e) { next(e); }
};
export const exportRevenue = async (req, res, next) => {
  try {
    const { from, to, group = "day", format = "csv" } = req.query;
    const grp = group === "month" ? "DATE_FORMAT(b.check_out,'%Y-%m')" : "DATE(b.check_out)";
    const params = [];
    let where = `WHERE p.status='completed'`;
    if (from) { where += ` AND b.check_out >= ?`; params.push(from); }
    if (to)   { where += ` AND b.check_out < DATE_ADD(?, INTERVAL 1 DAY)`; params.push(to); }

    // dataset gộp theo period + theo khách sạn (để pivot/filter sau)
    const [rows] = await pool.query(
      `SELECT ${grp} AS period, h.id AS hotel_id, h.name AS hotel_name,
              SUM(p.amount) AS revenue, COUNT(DISTINCT b.id) AS bookings
         FROM payments p
         JOIN bookings b ON b.id=p.booking_id
         JOIN rooms r ON r.id=b.room_id
         JOIN hotels h ON h.id=r.hotel_id
        ${where}
        GROUP BY period, h.id, h.name
        ORDER BY period ASC, revenue DESC`,
      params
    );

    if ((format || "").toLowerCase() === "xlsx") {
      // ====== Excel (cần: npm i exceljs) ======
      // import động để không bắt buộc cài nếu bạn chỉ dùng CSV
      const ExcelJS = (await import("exceljs")).default;
      const wb = new ExcelJS.Workbook();
      const ws = wb.addWorksheet("Revenue");

      ws.columns = [
        { header: "Period", key: "period", width: 15 },
        { header: "Hotel ID", key: "hotel_id", width: 10 },
        { header: "Hotel Name", key: "hotel_name", width: 30 },
        { header: "Bookings", key: "bookings", width: 12 },
        { header: "Revenue", key: "revenue", width: 15 }
      ];
      rows.forEach(r => ws.addRow({
        period: r.period,
        hotel_id: r.hotel_id,
        hotel_name: r.hotel_name,
        bookings: Number(r.bookings) || 0,
        revenue: Number(r.revenue) || 0
      }));

      res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      res.setHeader("Content-Disposition", `attachment; filename="revenue_${group}.xlsx"`);
      const buffer = await wb.xlsx.writeBuffer();
      return res.status(200).send(Buffer.from(buffer));
    }

    // ====== CSV (mặc định) ======
    const header = ["period","hotel_id","hotel_name","bookings","revenue"];
    const lines = [header.join(",")];
    for (const r of rows) {
      const row = [
        r.period,
        r.hotel_id,
        `"${String(r.hotel_name).replace(/"/g, '""')}"`,
        Number(r.bookings) || 0,
        Number(r.revenue) || 0
      ];
      lines.push(row.join(","));
    }
    const csv = lines.join("\n");

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="revenue_${group}.csv"`);
    return res.status(200).send(csv);
  } catch (e) { next(e); }
};
