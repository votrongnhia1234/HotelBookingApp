import pool from "../config/db.js";

export const listHotels = async (req, res, next) => {
  try {
    const { q, city, page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    const filters = [];
    const params = [];

    if (q) { filters.push("(name LIKE ? OR description LIKE ?)"); params.push(`%${q}%`, `%${q}%`); }
    if (city) { filters.push("city = ?"); params.push(city); }

    const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";

    const [rows] = await pool.query(
      `SELECT id, name, description, address, city, country, rating, created_at
       FROM hotels
       ${where}
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, Number(limit), offset]
    );

    res.json({ data: rows, page: Number(page), limit: Number(limit) });
  } catch (e) { next(e); }
};

export const getHotelCities = async (req, res, next) => {
  try {
    const { q, limit } = req.query;
    const params = [];
    let sql =
      `SELECT city, COUNT(*) AS hotels
       FROM hotels
       WHERE city IS NOT NULL AND city <> ''`;

    if (q && q.trim()) {
      sql += ` AND city LIKE ?`;
      params.push(`%${q.trim()}%`);
    }

    sql += ` GROUP BY city
             HAVING hotels > 0
             ORDER BY city ASC`;

    if (limit && /^\d+$/.test(String(limit))) {
      sql += ` LIMIT ?`;
      params.push(Number(limit));
    }

    const [rows] = await pool.query(sql, params);

    // Chuẩn hoá về mảng [{city, hotels}]
    const data = rows.map(r => ({
      city: String(r.city),
      hotels: Number(r.hotels),
    }));

    res.json({ data, total: data.length });
  } catch (err) {
    next(err);
  }
};
