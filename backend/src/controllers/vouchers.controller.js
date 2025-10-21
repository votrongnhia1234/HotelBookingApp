import pool from "../config/db.js";
import { managerOwnsHotel } from "./_ownership.util.js";
import { recordAudit } from "../utils/audit.js";

const DEFAULT_VOUCHERS = [
  {
    id: 1,
    code: "WELCOME10",
    title: "Giảm 10% cho khách mới",
    description: "Áp dụng cho đơn đặt phòng đầu tiên của bạn.",
    discount_type: "percent",
    value: 10,
    min_order: 500000,
    online_only: false,
    hotel_id: null,
    nights_required: null,
  },
  {
    id: 2,
    code: "ONLINE50K",
    title: "Giảm 50.000₫ khi thanh toán online",
    description: "Chỉ áp dụng cho phương thức thanh toán trực tuyến.",
    discount_type: "amount",
    value: 50000,
    min_order: 300000,
    online_only: true,
    hotel_id: null,
    nights_required: null,
  },
  {
    id: 3,
    code: "LONGSTAY15",
    title: "Ưu đãi lưu trú dài ngày",
    description: "Giảm 15% cho đơn từ 3 đêm trở lên.",
    discount_type: "percent",
    value: 15,
    min_order: 0,
    online_only: false,
    hotel_id: null,
    nights_required: 3,
  },
];

export const listVouchers = async (req, res, next) => {
  try {
    const userId = Number(req.query.userId ?? req.user?.id ?? 0);
    const vouchers = await fetchVouchersFromDb(userId);
    res.json({ data: vouchers });
  } catch (err) {
    next(err);
  }
};

export const createVoucher = async (req, res, next) => {
  try {
    const role = req.user?.role ?? "customer";
    const userId = req.user?.id;
    const body = req.body ?? {};

    const discountType = String(body.discountType ?? body.discount_type ?? "amount").toLowerCase();
    const value = Number(body.value ?? 0);
    const code = String(body.code ?? "").trim();
    const title = String(body.title ?? "").trim();

    if (!code || !title || !["percent", "amount"].includes(discountType) || Number.isNaN(value)) {
      return res.status(400).json({ message: "code, title, discountType and value are required" });
    }

    let hotelId = body.hotelId ?? body.hotel_id ?? null;
    if (hotelId != null) hotelId = Number(hotelId);

    if (role === "hotel_manager") {
      if (!hotelId) {
        return res.status(400).json({ message: "hotel_id is required for partner vouchers" });
      }
      const owns = await managerOwnsHotel(userId, hotelId);
      if (!owns) {
        return res.status(403).json({ message: "Bạn không có quyền tạo voucher cho khách sạn này" });
      }
    }

    const expiry = normalizeDate(body.expiry ?? body.expiry_date);
    const payload = [
      code,
      title,
      String(body.description ?? ""),
      discountType,
      value,
      body.minOrder ?? body.min_order ?? null,
      body.onlineOnly ?? body.online_only ? 1 : 0,
      expiry,
      body.nightsRequired ?? body.nights_required ?? null,
      body.isActive ?? body.is_active ?? 1,
      hotelId,
      userId ?? null,
    ];

    const [result] = await pool.query(
      `INSERT INTO vouchers
         (code, title, description, discount_type, value, min_order, online_only, expiry_date, nights_required, is_active, hotel_id, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      payload,
    );

    const created = await fetchVoucherById(result.insertId, userId ?? 0);

    await recordAudit({
      userId,
      action: "voucher.create",
      targetType: "voucher",
      targetId: created?.id ?? result.insertId,
      metadata: {
        code,
        discountType,
        value,
        hotelId,
        role,
      },
    });

    res.status(201).json({ data: created });
  } catch (err) {
    if (err?.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Mã voucher đã tồn tại" });
    }
    if (err?.code === "ER_NO_SUCH_TABLE") {
      return res.status(500).json({ message: "Chưa có bảng vouchers. Vui lòng chạy schema.sql mới nhất." });
    }
    next(err);
  }
};

export const updateVoucher = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      return res.status(400).json({ message: "Voucher id không hợp lệ" });
    }

    const role = req.user?.role ?? "customer";
    const userId = req.user?.id;

    const existing = await fetchRawVoucher(id);
    if (!existing) {
      return res.status(404).json({ message: "Không tìm thấy voucher" });
    }

    if (role === "hotel_manager") {
      if (!existing.hotel_id) {
        return res.status(403).json({ message: "Bạn không được sửa voucher hệ thống" });
      }
      const owns = await managerOwnsHotel(userId, existing.hotel_id);
      if (!owns) {
        return res.status(403).json({ message: "Bạn không có quyền sửa voucher này" });
      }
    }

    const body = req.body ?? {};
    const updates = [];
    const values = [];

    if (body.title !== undefined) {
      updates.push("title = ?");
      values.push(String(body.title));
    }
    if (body.description !== undefined) {
      updates.push("description = ?");
      values.push(String(body.description ?? ""));
    }
    if (body.discountType !== undefined || body.discount_type !== undefined) {
      const type = String(body.discountType ?? body.discount_type).toLowerCase();
      if (!["percent", "amount"].includes(type)) {
        return res.status(400).json({ message: "discountType phải là percent hoặc amount" });
      }
      updates.push("discount_type = ?");
      values.push(type);
    }
    if (body.value !== undefined) {
      const value = Number(body.value);
      if (Number.isNaN(value)) {
        return res.status(400).json({ message: "value phải là số" });
      }
      updates.push("value = ?");
      values.push(value);
    }
    if (body.minOrder !== undefined || body.min_order !== undefined) {
      const minOrder = body.minOrder ?? body.min_order;
      updates.push("min_order = ?");
      values.push(minOrder == null ? null : Number(minOrder));
    }
    if (body.onlineOnly !== undefined || body.online_only !== undefined) {
      const online = body.onlineOnly ?? body.online_only;
      updates.push("online_only = ?");
      values.push(online ? 1 : 0);
    }
    if (body.expiry !== undefined || body.expiry_date !== undefined) {
      updates.push("expiry_date = ?");
      values.push(normalizeDate(body.expiry ?? body.expiry_date));
    }
    if (body.nightsRequired !== undefined || body.nights_required !== undefined) {
      const nights = body.nightsRequired ?? body.nights_required;
      updates.push("nights_required = ?");
      values.push(nights == null ? null : Number(nights));
    }
    if (body.isActive !== undefined || body.is_active !== undefined) {
      const active = body.isActive ?? body.is_active;
      updates.push("is_active = ?");
      values.push(active ? 1 : 0);
    }
    if (role === "admin" && (body.hotelId !== undefined || body.hotel_id !== undefined)) {
      const hotelId = body.hotelId ?? body.hotel_id;
      updates.push("hotel_id = ?");
      values.push(hotelId == null ? null : Number(hotelId));
    }
    if (role === "admin" && body.code !== undefined) {
      updates.push("code = ?");
      values.push(String(body.code).trim());
    }

    if (!updates.length) {
      return res.status(400).json({ message: "Không có nội dung cần cập nhật" });
    }

    values.push(id);

    await pool.query(`UPDATE vouchers SET ${updates.join(", ")} WHERE id = ?`, values);
    const updated = await fetchVoucherById(id, userId ?? 0);

    await recordAudit({
      userId,
      action: "voucher.update",
      targetType: "voucher",
      targetId: id,
      metadata: {
        role,
        changes: Object.fromEntries(
          updates.map((stmt, idx) => [stmt.split(" = ")[0], values[idx]]),
        ),
      },
    });

    res.json({ data: updated });
  } catch (err) {
    if (err?.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Mã voucher đã tồn tại" });
    }
    if (err?.code === "ER_NO_SUCH_TABLE") {
      return res.status(500).json({ message: "Chưa có bảng vouchers. Vui lòng chạy schema.sql mới nhất." });
    }
    next(err);
  }
};

export const deleteVoucher = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      return res.status(400).json({ message: "Voucher id không hợp lệ" });
    }
    const [result] = await pool.query("UPDATE vouchers SET is_active = 0 WHERE id = ?", [id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Không tìm thấy voucher" });
    }

    await recordAudit({
      userId: req.user?.id,
      action: "voucher.delete",
      targetType: "voucher",
      targetId: id,
    });

    res.json({ message: "Đã vô hiệu hóa voucher" });
  } catch (err) {
    if (err?.code === "ER_NO_SUCH_TABLE") {
      return res.status(500).json({ message: "Chưa có bảng vouchers. Vui lòng chạy schema.sql mới nhất." });
    }
    next(err);
  }
};

async function fetchVouchersFromDb(userId) {
  try {
    const [rows] = await pool.query(
      `SELECT id,
              code,
              title,
              description,
              discount_type,
              value,
              min_order,
              online_only,
              expiry_date,
              nights_required,
              is_active,
              hotel_id
         FROM vouchers
        WHERE (is_active = 1 OR is_active IS NULL)
        ORDER BY expiry_date IS NULL DESC, expiry_date ASC`,
    );

    if (!rows.length) {
      return decorateDefaultVouchers(userId);
    }

    return rows.map((row) => formatVoucherRow(row, userId));
  } catch (err) {
    return decorateDefaultVouchers(userId);
  }
}

async function fetchVoucherById(id, userId) {
  const row = await fetchRawVoucher(id);
  if (!row) return null;
  return formatVoucherRow(row, userId);
}

async function fetchRawVoucher(id) {
  const [rows] = await pool.query(
    `SELECT id,
            code,
            title,
            description,
            discount_type,
            value,
            min_order,
            online_only,
            expiry_date,
            nights_required,
            is_active,
            hotel_id
       FROM vouchers
      WHERE id = ?
      LIMIT 1`,
    [id],
  );
  return rows[0] ?? null;
}

function formatVoucherRow(row, userId) {
  return {
    id: Number(row.id),
    code: String(row.code ?? ""),
    title: String(row.title ?? ""),
    description: String(row.description ?? ""),
    discountType: String(row.discount_type ?? "amount"),
    value: Number(row.value ?? 0),
    minOrder: row.min_order == null ? null : Number(row.min_order),
    onlineOnly: Boolean(row.online_only),
    expiry: row.expiry_date ? formatDate(row.expiry_date) : null,
    nightsRequired: row.nights_required == null ? null : Number(row.nights_required),
    recommended: recommendForUser(userId, row),
  };
}

function decorateDefaultVouchers(userId) {
  return DEFAULT_VOUCHERS.map((voucher) =>
    formatVoucherRow(
      {
        ...voucher,
        is_active: 1,
        expiry_date: null,
      },
      userId,
    ),
  );
}

function recommendForUser(userId, voucher) {
  if (!userId) return false;
  if (voucher.hotel_id) return true;
  if (voucher.online_only) return true;
  if (voucher.nights_required && voucher.nights_required >= 3) return true;
  return false;
}

function normalizeDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return formatDate(date);
}

function formatDate(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}
