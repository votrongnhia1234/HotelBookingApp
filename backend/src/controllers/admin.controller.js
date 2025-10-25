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
    if (!rows.length) return res.status(404).json({ message: "Không tìm thấy người dùng", code: "NOT_FOUND" });
    res.json(rows[0]);
  } catch (e) { next(e); }
};

// POST /admin/users  { name,email,password,role,phone,address }
export const createUser = async (req, res, next) => {
  try {
    const { name, email, password, role="customer", phone, address } = req.body;
    if (!name || !email || !password) return res.status(400).json({ message: "name, email, password required", code: "VALIDATION_ERROR" });

    const [[dupe]] = await pool.query(`SELECT id FROM users WHERE email=? LIMIT 1`, [email]);
    if (dupe) return res.status(409).json({ message: "Email already exists", code: "EMAIL_IN_USE" });

    const [[roleRow]] = await pool.query(`SELECT id FROM roles WHERE role_name=? LIMIT 1`, [role]);
    if (!roleRow) return res.status(400).json({ message: "Invalid role", code: "INVALID_ROLE" });

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
    if (!fields.length) return res.status(400).json({ message: "Không có trường nào cần cập nhật", code: "NO_FIELDS_TO_UPDATE" });

    params.push(id);
    const [r] = await pool.query(`UPDATE users SET ${fields.join(",")} WHERE id=?`, params);
    if (r.affectedRows === 0) return res.status(404).json({ message: "Không tìm thấy người dùng", code: "NOT_FOUND" });
    res.json({ message: "Cập nhật người dùng thành công" });
  } catch (e) { next(e); }
};

// PATCH /admin/users/:id/role  { role }
export const changeUserRole = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { role } = req.body;
    if (!role) return res.status(400).json({ message: "Cần truyền vai trò (role)", code: "VALIDATION_ERROR" });
    const [[roleRow]] = await pool.query(`SELECT id FROM roles WHERE role_name=? LIMIT 1`, [role]);
    if (!roleRow) return res.status(400).json({ message: "Vai trò không hợp lệ", code: "INVALID_ROLE" });

    const [r] = await pool.query(`UPDATE users SET role_id=? WHERE id=?`, [roleRow.id, id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "Không tìm thấy người dùng", code: "NOT_FOUND" });
    res.json({ message: "Cập nhật vai trò thành công", role });
  } catch (e) { next(e); }
};

// PATCH /admin/users/:id/deactivate  (soft lock user bằng đặt password null hoặc flag)
export const deactivateUser = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    // Cách đơn giản: đặt password = NULL để chặn login (hoặc thêm cột is_active TINYINT(1))
    const [r] = await pool.query(`UPDATE users SET password=NULL WHERE id=?`, [id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "User not found", code: "NOT_FOUND" });
    res.json({ message: "User deactivated" });
  } catch (e) { next(e); }
};

// DELETE /admin/users/:id (xóa cứng)
export const deleteUser = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const [r] = await pool.query(`DELETE FROM users WHERE id=?`, [id]);
    if (r.affectedRows === 0) return res.status(404).json({ message: "User not found", code: "NOT_FOUND" });
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
      const ws = wb.addWorksheet("Doanh thu");

      ws.columns = [
        { header: "Kỳ", key: "period", width: 15 },
        { header: "Mã KS", key: "hotel_id", width: 10 },
        { header: "Tên khách sạn", key: "hotel_name", width: 30 },
        { header: "Số đơn", key: "bookings", width: 12 },
        { header: "Doanh thu", key: "revenue", width: 15 }
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
    const header = ["ky","ma_khach_san","ten_khach_san","so_don","doanh_thu"];
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

export const assignHotelManager = async (req, res, next) => {
  try {
    const hotelId = Number(req.params.id);
    const { user_id } = req.body;
    if (!hotelId || !Number.isFinite(hotelId)) {
      return res.status(400).json({ message: "hotel_id không hợp lệ", code: "VALIDATION_ERROR" });
    }
    if (!user_id || !Number.isFinite(Number(user_id))) {
      return res.status(400).json({ message: "Cần truyền user_id", code: "VALIDATION_ERROR" });
    }

    const [[hotel]] = await pool.query(`SELECT id FROM hotels WHERE id=? LIMIT 1`, [hotelId]);
    if (!hotel) return res.status(404).json({ message: "Không tìm thấy khách sạn", code: "NOT_FOUND" });

    const [[user]] = await pool.query(
      `SELECT u.id, r.role_name AS role
         FROM users u JOIN roles r ON r.id=u.role_id
        WHERE u.id=? LIMIT 1`,
      [Number(user_id)]
    );
    if (!user) return res.status(404).json({ message: "Không tìm thấy người dùng", code: "NOT_FOUND" });
    if (user.role !== "hotel_manager") {
      return res.status(400).json({ message: "Người dùng phải có vai trò 'hotel_manager'", code: "INVALID_ROLE" });
    }

    const [[existing]] = await pool.query(
      `SELECT id FROM hotel_managers WHERE hotel_id=? AND user_id=? LIMIT 1`,
      [hotelId, Number(user_id)]
    );
    if (existing) return res.status(409).json({ message: "Người dùng đã quản lý khách sạn này", code: "CONFLICT" });

    const [r] = await pool.query(
      `INSERT INTO hotel_managers (hotel_id, user_id) VALUES (?, ?)`,
      [hotelId, Number(user_id)]
    );

    res.status(201).json({
      id: r.insertId,
      hotel_id: hotelId,
      user_id: Number(user_id),
    });
  } catch (e) { next(e); }
};

export const removeHotelManager = async (req, res, next) => {
  try {
    const hotelId = Number(req.params.id);
    const userId = Number(req.params.userId);
    if (!Number.isFinite(hotelId) || !Number.isFinite(userId)) {
      return res.status(400).json({ message: "Invalid hotel_id or userId", code: "VALIDATION_ERROR" });
    }
    const [r] = await pool.query(
      `DELETE FROM hotel_managers WHERE hotel_id=? AND user_id=?`,
      [hotelId, userId]
    );
    if (r.affectedRows === 0) return res.status(404).json({ message: "Assignment not found", code: "NOT_FOUND" });
    res.json({ message: "Manager unassigned from hotel" });
  } catch (e) { next(e); }
};

export const exportRevenueSummary = async (req, res, next) => {
  try {
    const today = todayISO();
    const [[{ revenueAll }]] = await pool.query(
      `SELECT COALESCE(SUM(CASE WHEN status='completed' THEN amount END),0) revenueAll FROM payments`
    );
    const [[{ revenueToday }]] = await pool.query(
      `SELECT COALESCE(SUM(p.amount),0) revenueToday
         FROM payments p JOIN bookings b ON b.id=p.booking_id
        WHERE p.status='completed' AND DATE(b.updated_at)=?`, [today]
    );

    const format = String(req.query.format || "xlsx").toLowerCase();
    if (format === "xlsx") {
      const ExcelJS = (await import("exceljs")).default;
      const wb = new ExcelJS.Workbook();
      const ws = wb.addWorksheet("Tổng quan");
      ws.columns = [
        { header: "Thời điểm", key: "as_of", width: 12 },
        { header: "Doanh thu (tổng)", key: "revenue_total", width: 18 },
        { header: "Doanh thu hôm nay", key: "revenue_today", width: 18 },
      ];
      ws.addRow({
        as_of: today,
        revenue_total: Number(revenueAll) || 0,
        revenue_today: Number(revenueToday) || 0,
      });

      res.setHeader("Content-Type","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      res.setHeader("Content-Disposition", `attachment; filename="revenue_summary_${today}.xlsx"`);
      const buffer = await wb.xlsx.writeBuffer();
      return res.status(200).send(Buffer.from(buffer));
    }

    const header = "thoi_diem,doanh_thu_tong,doanh_thu_hom_nay";
    const row = `${today},${Number(revenueAll)||0},${Number(revenueToday)||0}`;
    res.setHeader("Content-Type","text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="revenue_summary_${today}.csv"`);
    return res.status(200).send(`${header}\n${row}`);
  } catch (e) { next(e); }
};

// === NEW: List managers of a hotel ===
export const listHotelManagersForHotel = async (req, res, next) => {
  try {
    const hotelId = Number(req.params.id);
    if (!Number.isFinite(hotelId) || hotelId <= 0) {
      return res.status(400).json({ message: "Invalid hotel_id", code: "VALIDATION_ERROR" });
    }
    const [[hotel]] = await pool.query(`SELECT id, name FROM hotels WHERE id=? LIMIT 1`, [hotelId]);
    if (!hotel) return res.status(404).json({ message: "Hotel not found", code: "NOT_FOUND" });

    const [rows] = await pool.query(
      `SELECT hm.user_id, u.name, u.email, hm.created_at AS assigned_at
         FROM hotel_managers hm
         JOIN users u ON u.id = hm.user_id
        WHERE hm.hotel_id = ?
        ORDER BY u.name ASC`,
      [hotelId]
    );
    return res.json({ hotel: { id: hotel.id, name: hotel.name }, data: rows });
  } catch (e) { next(e); }
};

// === NEW: Export managers mapping (global or per hotel) ===
export const exportHotelManagers = async (req, res, next) => {
  try {
    const hotelIdParam = req.params.id ? Number(req.params.id) : null;
    const format = String(req.query.format || "xlsx").toLowerCase();

    const params = [];
    let where = "";
    if (hotelIdParam && Number.isFinite(hotelIdParam)) {
      where = "WHERE hm.hotel_id = ?";
      params.push(hotelIdParam);
    }

    const [rows] = await pool.query(
      `SELECT h.id AS hotel_id, h.name AS hotel_name,
              hm.user_id AS manager_user_id,
              u.name AS manager_name,
              u.email AS manager_email,
              hm.created_at AS assigned_at
         FROM hotel_managers hm
         JOIN hotels h ON h.id = hm.hotel_id
         JOIN users u ON u.id = hm.user_id
        ${where}
        ORDER BY h.name ASC, u.name ASC`,
      params
    );

    const today = todayISO();
    const baseName = hotelIdParam ? `hotel_${hotelIdParam}_managers_${today}` : `hotel_managers_${today}`;

    if (format === "xlsx") {
      const ExcelJS = (await import("exceljs")).default;
      const wb = new ExcelJS.Workbook();
      const ws = wb.addWorksheet("HotelManagers");
      ws.columns = [
        { header: "Hotel ID", key: "hotel_id", width: 10 },
        { header: "Hotel Name", key: "hotel_name", width: 30 },
        { header: "Manager User ID", key: "manager_user_id", width: 16 },
        { header: "Manager Name", key: "manager_name", width: 20 },
        { header: "Manager Email", key: "manager_email", width: 25 },
        { header: "Assigned At", key: "assigned_at", width: 20 },
      ];
      rows.forEach(r => ws.addRow({
        hotel_id: r.hotel_id,
        hotel_name: r.hotel_name,
        manager_user_id: r.manager_user_id,
        manager_name: r.manager_name,
        manager_email: r.manager_email,
        assigned_at: r.assigned_at,
      }));

      res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      res.setHeader("Content-Disposition", `attachment; filename="${baseName}.xlsx"`);
      const buffer = await wb.xlsx.writeBuffer();
      return res.status(200).send(Buffer.from(buffer));
    }

    // CSV fallback
    const header = [
      "hotel_id","hotel_name","manager_user_id","manager_name","manager_email","assigned_at"
    ];
    const lines = [header.join(",")];
    for (const r of rows) {
      const esc = (v) => `"${String(v ?? "").replace(/"/g,'""')}"`;
      lines.push([
        r.hotel_id,
        esc(r.hotel_name),
        r.manager_user_id,
        esc(r.manager_name),
        esc(r.manager_email),
        esc(r.assigned_at)
      ].join(","));
    }
    const csv = lines.join("\n");
    res.setHeader("Content-Type","text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="${baseName}.csv"`);
    return res.status(200).send(csv);
  } catch (e) { next(e); }
};
