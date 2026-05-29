const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
require("dotenv").config();

const foodRoutes = require("./routes/food");
const userRoutes = require("./routes/user");
const { router: authRoutes } = require("./routes/auth");
const analyticsRoutes = require("./routes/analytics");
const historyRoutes = require("./routes/history");
const notificationRoutes = require("./routes/notifications");
const setNotificationRoutes = require("./routes/setNotification");

const app = express();

app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));

// Request Logger Middleware
app.use((req, res, next) => {
  const size = req.body ? JSON.stringify(req.body).length : 0;
  console.log(`[Request] ${req.method} ${req.originalUrl} - Payload Size: ${size} bytes`);
  next();
});

// Connect to MongoDB
const MONGO_URI = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/neutraAI";
mongoose
  .connect(MONGO_URI)
  .then(() => console.log("Connected to MongoDB"))
  .catch((err) => console.error("MongoDB connection error:", err));

app.use("/api", foodRoutes);
app.use("/api/user", userRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/analytics", analyticsRoutes);
app.use("/api/history", historyRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/setNotification", setNotificationRoutes);

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log("Server running on port", PORT);
});