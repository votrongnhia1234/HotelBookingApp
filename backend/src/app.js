import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import router from "./routes/index.routes.js";
import { stripeWebhookHandler } from "./routes/payments.routes.js";
import { notFound, errorHandler } from "./middleware/error.js";
import path from 'path';
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import { startBookingTtlWorker } from "./workers/booking_ttl.js";
import swaggerUi from "swagger-ui-express";
import { openApiSpec } from "./docs/openapi.js";
import morgan from "morgan";
import { startAdminReportsWorker } from "./workers/admin_reports.js";

dotenv.config();
const app = express();

// Security headers
app.use(helmet());

// Request logging
morgan.token('userId', (req) => (req.user?.id ? String(req.user.id) : '-'));
const logFormat = process.env.NODE_ENV === 'production'
  ? ':remote-addr :method :url :status :res[content-length] - :response-time ms user=:userId'
  : ':method :url :status :response-time ms user=:userId';
app.use(morgan(logFormat));

// Restrictive CORS based on env CORS_ORIGINS (comma-separated)
const allowedOrigins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

// Common dev origins to make local web/mobile work out-of-the-box
const devOrigins = [
  'http://localhost:5600',
  'http://127.0.0.1:5600',
  'http://localhost:5173',
  // Allow Flutter web dev server
  'http://localhost:5608',
  'http://127.0.0.1:5608',
];
const isProd = process.env.NODE_ENV === 'production';
const isLocalhostOrigin = (origin) => {
  try {
    const u = new URL(origin);
    return u.hostname === 'localhost' || u.hostname === '127.0.0.1';
  } catch (_) {
    return false;
  }
};

app.use(
  cors({
    origin: (origin, cb) => {
      // allow non-browser or same-origin requests
      if (!origin) return cb(null, true);
      const whitelist = allowedOrigins.length
        ? (isProd ? allowedOrigins : [...new Set([...allowedOrigins, ...devOrigins])])
        : devOrigins;
      const ok =
        whitelist.includes(origin) ||
        (!isProd && isLocalhostOrigin(origin)) ||
        (!allowedOrigins.length && !isProd);
      if (ok) return cb(null, true);
      return cb(new Error("Not allowed by CORS"));
    },
    credentials: true,
    methods: ['GET','HEAD','PUT','PATCH','POST','DELETE','OPTIONS'],
    allowedHeaders: ['Authorization','Content-Type','Accept','X-Requested-With'],
    optionsSuccessStatus: 204,
  })
);

// Rate limits for sensitive routes
const standardLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
});
const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});

// JSON parsing
app.use(express.json());

// Serve uploads statically with cache headers
// Prefer project-root/uploads, then fallback to backend/uploads
const uploadsDirs = [
  path.resolve(process.cwd(), '..', 'uploads'),
  path.resolve(process.cwd(), 'uploads'),
];
uploadsDirs.forEach((dir) => {
  app.use('/uploads', express.static(dir, {
    maxAge: '7d',
    etag: true,
    immutable: false,
  }));
});

// Stripe webhook must be raw body
app.post('/api/payments/webhook', express.raw({ type: 'application/json' }), stripeWebhookHandler);

// Rate-limit for auth and payments
app.use('/api/auth', strictLimiter);
app.use('/api/payments', strictLimiter);
app.use('/api', standardLimiter);

// API routes
app.use('/api', router);

// Swagger UI
app.use('/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec));

// Health check for uptime monitors and mobile app
app.get('/health', (req, res) => {
  res.status(200).json({ message: 'Server OK' });
});

// 404 and error handler
app.use(notFound);
app.use(errorHandler);

// Start TTL worker
startBookingTtlWorker();
// Start admin reports worker
startAdminReportsWorker();

export default app;