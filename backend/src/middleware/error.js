export const notFound = (req, res, next) => {
  res.status(404).json({ message: "Không tìm thấy đường dẫn", code: "NOT_FOUND" });
};

export const errorHandler = (err, req, res, next) => {
  console.error(err);
  // Map một số lỗi upload (multer) về 400
  if (err?.code === 'LIMIT_FILE_SIZE') {
    err.statusCode = 400;
    err.code = 'UPLOAD_VALIDATION_ERROR';
    err.message = 'Kích thước file vượt quá giới hạn 5MB';
  }
  if (typeof err?.message === 'string' && err.message.startsWith('Invalid file type')) {
    err.statusCode = 400;
    err.code = 'UPLOAD_VALIDATION_ERROR';
  }

  const status = err.statusCode || 500;
  const code = err.code || (status === 500 ? "INTERNAL_ERROR" : undefined);
  const payload = {
    message: err.message || "Lỗi máy chủ",
  };
  if (code) payload.code = code;
  if (Array.isArray(err.errors)) payload.errors = err.errors;
  res.status(status).json(payload);
};
