import app from "./app.js";

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
// health route moved to app.js (registered before 404 middleware)

