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
- For troubleshooting, check `server.log` or console for "Failed to send login notification email" logs.