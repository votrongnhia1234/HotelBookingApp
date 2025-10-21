import pool from "../config/db.js";

export const recordAudit = async ({
  userId = null,
  action,
  targetType = null,
  targetId = null,
  metadata = null,
}) => {
  if (!action) return;
  try {
    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_type, target_id, metadata)
       VALUES (?, ?, ?, ?, ?)`,
      [
        userId ?? null,
        action,
        targetType,
        targetId == null ? null : String(targetId),
        metadata ? JSON.stringify(metadata) : null,
      ],
    );
  } catch (err) {
    if (process.env.NODE_ENV !== "production") {
      console.error("Failed to record audit log", err);
    }
  }
};
