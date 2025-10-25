# StayEasy Backend

This backend powers the StayEasy app (Node.js/Express + MySQL). It supports email notifications on Google/Firebase login, Stripe payments, and role-based access control.

## Setup

1. Install dependencies:
   - `npm install`
2. Create `.env` by copying `.env.example` and filling in values.
3. Import `schema.sql` into your MySQL database (or run migrations if you have them).
4. Start the server:
   - `npm run dev` (if configured) or `node src/server.js`

## Environment (.env)

Minimal required variables:

- Database: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- JWT: `JWT_SECRET`, `BCRYPT_SALT_ROUNDS`
- SMTP: `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`
- Stripe: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- OpenTripMap: `OPENTRIPMAP_KEY`
- CORS: `CORS_ORIGINS` (comma-separated list of allowed origins, e.g. `http://localhost:3000,http://127.0.0.1:3000`)
- Booking TTL: `BOOKING_PENDING_TTL_MINUTES` (minutes to auto-cancel pending bookings, default `15`)

### Security & Rate Limits

- Security headers are enabled via `helmet`.
- Rate limits are applied on `/api/auth` and `/api/payments`.
- Static uploads under `backend/uploads` are served with cache headers.

### Request Validation

- Zod-based validation is applied to critical endpoints:
  - `POST /api/bookings` requires `room_id` (number), `check_in` and `check_out` (YYYY-MM-DD, `check_out` after `check_in`).
  - `PATCH /api/bookings/:id/status` requires `status` in `pending|confirmed|cancelled`.
  - `POST /api/payments` requires `booking_id` (number), `amount` (>= 0), optional `method` and `currency`.
  - `POST /api/payments/confirm-demo` requires `booking_id` and `amount` (>= 0), optional `currency`.
- Validation errors return HTTP 400 with the shape `{ message, code: "VALIDATION_ERROR", errors: [{ path, message }] }`.

### Booking TTL Worker

- A background worker cancels stale `pending` bookings older than `BOOKING_PENDING_TTL_MINUTES`.
- Runs every minute and uses MySQL named locks to avoid concurrent runs across instances.
- Logs how many bookings were auto-cancelled.

### Stripe Webhook Idempotency

- The endpoint `/api/payments/webhook` verifies signatures and processes events transactionally.
- Events are recorded in `webhook_events` with a unique `(provider,event_id)` key to prevent duplicate processing.
- If a duplicate event is received, it is acknowledged but skipped.

### Email Notification on Google/Firebase Login

The endpoint `/api/auth/firebase` accepts a Firebase `idToken`. When a user logs in with Google, the backend:

- Decodes the Firebase token to fetch user info (name/email/phone).
- Ensures a StayEasy user record exists (creates one if needed).
- Issues a JWT (`token`).
- Sends a login notification email to the user's real email (if present), using Nodemailer.

Make sure SMTP settings are correct to allow sending emails.

#### Configure SMTP (Gmail example)

- Generate an App Password (recommended) in Google Account → Security → App passwords.
- Set:
  - `SMTP_HOST=smtp.gmail.com`
  - `SMTP_PORT=465`
  - `SMTP_SECURE=true`
  - `SMTP_USER=your_gmail@gmail.com`
  - `SMTP_PASS=your_app_password`
  - `SMTP_FROM="StayEasy <no-reply@stayeasy.app>"`

If not using Gmail, fill in SMTP credentials from your provider (SendGrid, Mailgun, etc.).

#### Test Flow

1. Run backend with `.env` configured.
2. In the StayEasy app, use Google Sign-In.
3. App exchanges Firebase `idToken` at `/api/auth/firebase`.
4. Check the inbox for the Google account used; you should see an email titled "Thông báo đăng nhập mới vào StayEasy".

Notes:

- Email sending is non-blocking; login succeeds even if SMTP fails.
- Backend avoids sending to a fallback synthetic email (used when provider doesn't supply real email).
- For troubleshooting, check `server.log` or console for logs like webhook processing and email send errors.