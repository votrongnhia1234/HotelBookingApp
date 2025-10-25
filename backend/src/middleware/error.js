export const notFound = (req, res, next) => {
  res.status(404).json({ message: "Không tìm thấy đường dẫn" });
};

export const errorHandler = (err, req, res, next) => {
  console.error(err);
  const status = err.statusCode || 500;
  res.status(status).json({
    message: err.message || "Lỗi máy chủ"
  });
};
