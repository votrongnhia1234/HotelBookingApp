import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import router from "./routes/index.routes.js";
import { stripeWebhookHandler } from "./routes/payments.routes.js";
import { notFound, errorHandler } from "./middleware/error.js";
import path from 'path';

dotenv.config();
const app = express();

app.use(cors());

// serve uploaded files
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

app.post("/api/payments/webhook", express.raw({ type: "application/json" }), stripeWebhookHandler);
app.use(express.json());

app.get("/", (_req, res) => res.json({ status: "ok" }));

app.use("/api", router);

app.use(notFound);
app.use(errorHandler);

export default app;
