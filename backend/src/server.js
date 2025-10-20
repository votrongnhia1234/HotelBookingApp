import app from "./app.js";

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
app.get("/health", (req, res) => {
  res.status(200).json({ message: "Server OK" });
});

