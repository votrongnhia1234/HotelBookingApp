let paymentsHasCurrencyCache = null;
let paymentsMethodEnumCache;
let paymentsStatusEnumCache;

const fetchEnumValues = async (pool, column) => {
  try {
    const [rows] = await pool.query(
      "SHOW COLUMNS FROM payments LIKE ?",
      [column],
    );
    if (!rows.length) return null;
    const type = String(rows[0].Type || rows[0].type || "").toLowerCase();
    if (!type.startsWith("enum(")) return null;
    const match = type.match(/^enum\((.*)\)$/i);
    if (!match) return null;
    return match[1]
      .split(",")
      .map((part) => part.trim().replace(/^'(.*)'$/, "$1"))
      .filter(Boolean);
  } catch (err) {
    return null;
  }
};

export const paymentsHasCurrencyColumn = async (pool) => {
  if (paymentsHasCurrencyCache !== null) {
    return paymentsHasCurrencyCache;
  }
  try {
    const [rows] = await pool.query(
      "SHOW COLUMNS FROM payments LIKE 'currency'"
    );
    paymentsHasCurrencyCache = rows.length > 0;
  } catch (err) {
    paymentsHasCurrencyCache = false;
  }
  return paymentsHasCurrencyCache;
};

export const paymentsMethodAllowedValues = async (pool) => {
  if (paymentsMethodEnumCache !== undefined) {
    return paymentsMethodEnumCache;
  }
  paymentsMethodEnumCache = await fetchEnumValues(pool, "method");
  return paymentsMethodEnumCache;
};

export const paymentsStatusAllowedValues = async (pool) => {
  if (paymentsStatusEnumCache !== undefined) {
    return paymentsStatusEnumCache;
  }
  paymentsStatusEnumCache = await fetchEnumValues(pool, "status");
  return paymentsStatusEnumCache;
};
