import nodemailer from 'nodemailer';

let cachedTransporter = null;

function buildTransporter() {
  const host = process.env.SMTP_HOST;
  const port = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : undefined;
  const secure = process.env.SMTP_SECURE === 'true';
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host) {
    console.warn('[email] SMTP_HOST is not set. Emails will be logged only.');
    return null;
  }

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: user ? { user, pass } : undefined,
  });
}

export function getTransporter() {
  if (cachedTransporter === null) {
    cachedTransporter = buildTransporter();
  }
  return cachedTransporter;
}

export async function sendEmail({ to, subject, text, html }) {
  const transporter = getTransporter();
  const from = process.env.SMTP_FROM || process.env.SMTP_USER || 'no-reply@stayeasy.example';

  if (!transporter) {
    console.log('[email:mock]', { to, subject, text, html });
    return { mocked: true };
  }

  const info = await transporter.sendMail({ from, to, subject, text, html });
  return info;
}

const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif','clp','djf','gnf','jpy','kmf','krw','mga','pyg','rwf','ugx','vnd','vuv','xaf','xof','xpf',
]);

export function displayAmount(minorUnits, currency) {
  const ccy = String(currency || 'usd').toLowerCase();
  const num = Number(minorUnits);
  if (!Number.isFinite(num)) return '—';
  const value = ZERO_DECIMAL_CURRENCIES.has(ccy) ? num : num / 100;
  return `${value.toLocaleString(undefined, { minimumFractionDigits: ZERO_DECIMAL_CURRENCIES.has(ccy) ? 0 : 2 })} ${ccy.toUpperCase()}`;
}

export function renderPaymentReceiptHtml({ booking, payment }) {
  const amountStr = displayAmount(payment.amount_minor, payment.currency);
  const checkIn = new Date(booking.check_in).toLocaleDateString();
  const checkOut = new Date(booking.check_out).toLocaleDateString();

  return `
    <div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:640px;margin:auto;padding:16px;border:1px solid #eee;border-radius:8px">
      <h2 style="margin:0 0 12px;color:#0d47a1">Hóa đơn thanh toán StayEasy</h2>
      <p>Xin chào ${booking.user_name || 'Quý khách'},</p>
      <p>Chúng tôi đã nhận được thanh toán cho đơn đặt phòng #${booking.id}.</p>

      <h3 style="margin:16px 0 8px">Thông tin đặt phòng</h3>
      <ul style="padding-left:16px;line-height:1.6">
        <li>Khách sạn: <strong>${booking.hotel_name}</strong></li>
        <li>Phòng: <strong>${booking.room_number}</strong> (${booking.room_type})</li>
        <li>Nhận phòng: <strong>${checkIn}</strong></li>
        <li>Trả phòng: <strong>${checkOut}</strong></li>
        <li>Số đêm: <strong>${booking.nights}</strong></li>
        <li>Tổng tiền phòng: <strong>${Number(booking.total_price).toLocaleString()} VND</strong></li>
      </ul>

      <h3 style="margin:16px 0 8px">Chi tiết thanh toán</h3>
      <ul style="padding-left:16px;line-height:1.6">
        <li>Phương thức: <strong>Stripe</strong></li>
        <li>Số tiền thanh toán: <strong>${amountStr}</strong></li>
        <li>Mã giao dịch: <code>${payment.transaction_id}</code></li>
        <li>Trạng thái: <strong>Thành công</strong></li>
      </ul>

      <p>Nếu bạn có bất kỳ câu hỏi nào, vui lòng phản hồi email này hoặc liên hệ hỗ trợ StayEasy.</p>
      <p style="margin-top:16px;color:#666">Cảm ơn bạn đã chọn StayEasy!</p>
    </div>
  `;
}

export async function sendPaymentReceipt({ to, booking, payment }) {
  const subject = `Hóa đơn thanh toán online #${booking.id} - StayEasy`;
  const html = renderPaymentReceiptHtml({ booking, payment });
  const text = `StayEasy xác nhận thanh toán thành công cho đặt phòng #${booking.id}. Số tiền: ${displayAmount(payment.amount_minor, payment.currency)}. Mã giao dịch: ${payment.transaction_id}.`;
  return sendEmail({ to, subject, text, html });
}

export function renderPaymentFailedHtml({ booking, payment }) {
  const amountStr = displayAmount(payment.amount_minor, payment.currency);
  return `
    <div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:640px;margin:auto;padding:16px;border:1px solid #eee;border-radius:8px">
      <h2 style="margin:0 0 12px;color:#b00020">Thanh toán thất bại</h2>
      <p>Đơn đặt phòng #${booking.id} chưa được thanh toán thành công.</p>
      <ul style="padding-left:16px;line-height:1.6">
        <li>Số tiền: <strong>${amountStr}</strong></li>
        <li>Mã giao dịch: <code>${payment.transaction_id}</code></li>
      </ul>
      <p>Vui lòng thử lại hoặc chọn phương thức thanh toán khác.</p>
    </div>
  `;
}

export async function sendPaymentFailed({ to, booking, payment }) {
  const subject = `Thanh toán thất bại cho đặt phòng #${booking.id} - StayEasy`;
  const html = renderPaymentFailedHtml({ booking, payment });
  const text = `Thanh toán online thất bại cho đặt phòng #${booking.id}. Số tiền: ${displayAmount(payment.amount_minor, payment.currency)}. Mã giao dịch: ${payment.transaction_id}.`;
  return sendEmail({ to, subject, text, html });
}