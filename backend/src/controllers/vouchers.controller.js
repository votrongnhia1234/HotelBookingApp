import pool from "../config/db.js";

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
  },
  {
    id: 3,
    code: "LONGSTAY15",
    title: "Ưu đãi lưu trú dài ngày",
    description: "Giảm 15% cho đơn từ 3 đêm trở lên.",
    discount_type: "percent",
    value: 15,
    min_order: 0,
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
              nights_required
         FROM vouchers
        WHERE (is_active = 1 OR is_active IS NULL)
        ORDER BY expiry_date IS NULL DESC, expiry_date ASC`
    );

    if (!rows.length) {
      return decorateDefaultVouchers(userId);
    }

    return rows.map((row) => ({
      id: Number(row.id),
      code: String(row.code ?? ""),
      title: String(row.title ?? ""),
      description: String(row.description ?? ""),
      discountType: String(row.discount_type ?? "amount"),
      value: Number(row.value ?? 0),
      minOrder: row.min_order == null ? null : Number(row.min_order),
      onlineOnly: Boolean(row.online_only),
      expiry: row.expiry_date,
      nightsRequired: row.nights_required == null ? null : Number(row.nights_required),
      recommended: recommendForUser(userId, row),
    }));
  } catch (err) {
    // Fallback to in-memory list if table is missing.
    return decorateDefaultVouchers(userId);
  }
}

function decorateDefaultVouchers(userId) {
  return DEFAULT_VOUCHERS.map((voucher) => ({
    id: voucher.id,
    code: voucher.code,
    title: voucher.title,
    description: voucher.description,
    discountType: voucher.discount_type,
    value: voucher.value,
    minOrder: voucher.min_order,
    onlineOnly: voucher.online_only ?? false,
    expiry: null,
    nightsRequired: voucher.nights_required ?? null,
    recommended: recommendForUser(userId, voucher),
  }));
}

function recommendForUser(userId, voucher) {
  if (!userId) return false;
  if (voucher.online_only) return true;
  if (voucher.nights_required && voucher.nights_required >= 3) {
    return userId % 2 === 0;
  }
  return userId % 2 === 1;
}
