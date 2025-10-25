import { z } from "zod";

const formatZodErrors = (error) => {
  return error.errors.map((e) => ({
    path: e.path.join("."),
    message: e.message,
  }));
};

export const validateBody = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body);
  if (!result.success) {
    const err = new Error("Yêu cầu không hợp lệ");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    err.errors = formatZodErrors(result.error);
    return next(err);
  }
  req.body = result.data;
  next();
};

export const validateQuery = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.query);
  if (!result.success) {
    const err = new Error("Tham số truy vấn không hợp lệ");
    err.statusCode = 400;
    err.code = "VALIDATION_ERROR";
    err.errors = formatZodErrors(result.error);
    return next(err);
  }
  req.query = result.data;
  next();
};