import pool from "../config/db.js";
import { sendAdminReport } from "../utils/email.js";

const RUN_INTERVAL_MS = Number(process.env.ADMIN_REPORT_RUN_INTERVAL_MS || (60 * 60 * 1000)); // default hourly
const DAILY_HOUR = Number(process.env.ADMIN_REPORT_DAILY_HOUR || 8); // 8 AM local

const todayISO = () => new Date(Date.now() - new Date().getTimezoneOffset()*60000).toISOString().slice(0,10);

export const startAdminReportsWorker = () => {
  if (!Number.isFinite(RUN_INTERVAL_MS) || RUN_INTERVAL_MS <= 0) {
    console.warn("[Reports] ADMIN_REPORT_RUN_INTERVAL_MS không hợp lệ, bỏ qua worker");
    return;
  }

  const run = async () => {
    const now = new Date();
    const hour = now.getHours();
    if (!Number.isFinite(DAILY_HOUR) || DAILY_HOUR < 0 || DAILY_HOUR > 23) {
      console.warn("[Reports] ADMIN_REPORT_DAILY_HOUR không hợp lệ, mặc định 8h");
    }
    const thresholdHour = Number.isFinite(DAILY_HOUR) ? DAILY_HOUR : 8;
    if (hour < thresholdHour) {
      return; // Chỉ chạy sau giờ cấu hình (mỗi ngày)
    }

    const conn = await pool.getConnection();
    try {
      const [[lock]] = await conn.query("SELECT GET_LOCK('admin_reports_worker', 0) AS got");
      if (lock.got !== 1) {
        return; // another instance running
      }

      try {
        const today = todayISO();
        await conn.query(`CREATE TABLE IF NOT EXISTS admin_report_runs (
          report_date DATE PRIMARY KEY,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )`);

        const [[existing]] = await conn.query(
          "SELECT report_date FROM admin_report_runs WHERE report_date=? LIMIT 1",
          [today]
        );
        if (existing) {
          return; // already sent today
        }

        // Build datasets for last 7 days
        const from = new Date(Date.now() - 6 * 24 * 60 * 60 * 1000);
        const fromISO = new Date(from.getTime() - from.getTimezoneOffset()*60000).toISOString().slice(0,10);

        // Conversion dataset
        const [convRows] = await conn.query(
          `SELECT DATE(b.created_at) AS period,
                  COUNT(*) AS created,
                  COUNT(CASE WHEN b.status='completed' THEN 1 END) AS completed,
                  COUNT(CASE WHEN b.status='cancelled' THEN 1 END) AS cancelled,
                  ROUND(100 * COUNT(CASE WHEN b.status='completed' THEN 1 END) / NULLIF(COUNT(*),0), 2) AS conversion_rate
             FROM bookings b
            WHERE b.created_at >= ? AND b.created_at < DATE_ADD(?, INTERVAL 1 DAY)
            GROUP BY period
            ORDER BY period ASC`,
          [fromISO, today]
        );
        const convHeader = ['ky','so_tao_moi','hoan_tat','huy','ty_le_%'];
        const convLines = [convHeader.join(',')];
        for (const r of convRows) {
          convLines.push([
            r.period,
            Number(r.created)||0,
            Number(r.completed)||0,
            Number(r.cancelled)||0,
            Number(r.conversion_rate)||0,
          ].join(','));
        }
        const convCsv = convLines.join('\n');

        // Cancellations & refunds dataset (required refunds based on completed payments)
        const [cancelRows] = await conn.query(
          `SELECT DATE(b.updated_at) AS period,
                  COUNT(*) AS cancelled_count,
                  COALESCE(SUM(b.total_price),0) AS cancelled_amount,
                  COUNT(DISTINCT CASE WHEN p.id IS NOT NULL AND p.status='completed' THEN b.id END) AS refunds_required_count,
                  COALESCE(SUM(CASE WHEN p.id IS NOT NULL AND p.status='completed' THEN p.amount END),0) AS refunds_required_amount
             FROM bookings b
        LEFT JOIN payments p ON p.booking_id=b.id
            WHERE b.status='cancelled' AND b.updated_at >= ? AND b.updated_at < DATE_ADD(?, INTERVAL 1 DAY)
            GROUP BY period
            ORDER BY period ASC`,
          [fromISO, today]
        );
        const cancelHeader = ['ky','so_huy','gia_tri_huy','refund_can_xu_ly','gia_tri_refund_can_xu_ly'];
        const cancelLines = [cancelHeader.join(',')];
        for (const r of cancelRows) {
          cancelLines.push([
            r.period,
            Number(r.cancelled_count)||0,
            Number(r.cancelled_amount)||0,
            Number(r.refunds_required_count)||0,
            Number(r.refunds_required_amount)||0,
          ].join(','));
        }
        const cancelCsv = cancelLines.join('\n');

        // Excel workbook with both sheets
        const ExcelJS = (await import('exceljs')).default;
        const wb = new ExcelJS.Workbook();
        const wsConv = wb.addWorksheet('ChuyenDoi');
        wsConv.columns = [
          { header: 'Ky', key: 'period', width: 15 },
          { header: 'So tao moi', key: 'created', width: 12 },
          { header: 'Hoan tat', key: 'completed', width: 12 },
          { header: 'Huy', key: 'cancelled', width: 12 },
          { header: 'Ty le (%)', key: 'conversion_rate', width: 12 },
        ];
        convRows.forEach(r => wsConv.addRow({
          period: r.period,
          created: Number(r.created)||0,
          completed: Number(r.completed)||0,
          cancelled: Number(r.cancelled)||0,
          conversion_rate: Number(r.conversion_rate)||0,
        }));

        const wsCanc = wb.addWorksheet('HuyHoanTien');
        wsCanc.columns = [
          { header: 'Ky', key: 'period', width: 15 },
          { header: 'So huy', key: 'cancelled_count', width: 10 },
          { header: 'Gia tri huy', key: 'cancelled_amount', width: 14 },
          { header: 'Refund can xu ly', key: 'refunds_required_count', width: 18 },
          { header: 'Gia tri refund can xu ly', key: 'refunds_required_amount', width: 24 },
        ];
        cancelRows.forEach(r => wsCanc.addRow({
          period: r.period,
          cancelled_count: Number(r.cancelled_count)||0,
          cancelled_amount: Number(r.cancelled_amount)||0,
          refunds_required_count: Number(r.refunds_required_count)||0,
          refunds_required_amount: Number(r.refunds_required_amount)||0,
        }));
        const xlsxBuffer = await wb.xlsx.writeBuffer();

        // Prepare recipients (admins + hotel managers)
        const [recipientsRows] = await conn.query(
          `SELECT u.email
             FROM users u JOIN roles r ON r.id = u.role_id
            WHERE r.role_name IN ('admin','hotel_manager') AND COALESCE(u.email,'') <> ''`
        );
        const recipients = recipientsRows.map(r => r.email).filter(Boolean);

        const attachments = [
          { filename: `conversion_${today}.csv`, content: convCsv, contentType: 'text/csv' },
          { filename: `cancellations_refunds_${today}.csv`, content: cancelCsv, contentType: 'text/csv' },
          { filename: `reports_${today}.xlsx`, content: Buffer.from(xlsxBuffer), contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' },
        ];

        const summary = `Phạm vi: ${fromISO} đến ${today}. Đính kèm 2 CSV và 1 XLSX.`;

        // Mark as sent (prevent duplicates) then attempt to send
        await conn.query("INSERT INTO admin_report_runs (report_date) VALUES (?)", [today]);

        for (const to of recipients) {
          try { await sendAdminReport({ to, date: today, attachments, summary }); }
          catch (err) { console.error('[Reports] Lỗi gửi email', to, err?.message || err); }
        }
      } finally {
        await conn.query("SELECT RELEASE_LOCK('admin_reports_worker')");
      }
    } catch (err) {
      console.error("[Reports] Lỗi worker:", err.message || err);
    } finally {
      conn.release();
    }
  };

  // first run after short delay
  setTimeout(run, 15 * 1000);
  setInterval(run, RUN_INTERVAL_MS);

  console.log(`[Reports] Admin reports worker khởi động, interval=${RUN_INTERVAL_MS}ms, dailyHour=${DAILY_HOUR}`);
};
