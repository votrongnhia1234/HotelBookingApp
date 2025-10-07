import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import router from "./routes/index.routes.js";
import { notFound, errorHandler } from "./middleware/error.js";

dotenv.config();
const app = express();

app.use(cors());  // Dùng cors từ import

app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

app.use(express.json());

app.get("/", (_req, res) => res.json({ status: "ok" }));

app.use("/api", router);

app.use(notFound);
app.use(errorHandler);

export default app;