const express = require("express");
const Notification = require("../models/Notification");
const User = require("../models/User");
const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    // Pre-populate user custom notifications if empty
    const user = await User.findOne({ userId });
    if (user && (!user.custom_notifications || user.custom_notifications.length === 0)) {
      user.custom_notifications = [
        { title: "💧 Drink Water", time: "08:00 AM", isOn: false, repeat: "None" },
        { title: "🍽️ Meal Logging", time: "01:00 PM", isOn: false, repeat: "None" },
        { title: "💪 Workout", time: "06:00 PM", isOn: false, repeat: "None" }
      ];
      await user.save();
      console.log(`[Route Notifications] Pre-populated default notifications for user: ${userId}`);
    }

    const notifications = await Notification.find({ userId }).sort({ createdAt: -1 });
    res.json(notifications);
  } catch (error) {
    console.error("Error fetching notifications:", error);
    res.status(500).json({ error: "Server error" });
  }
});

router.post("/read/:id", async (req, res) => {
  try {
    const { id } = req.params;
    await Notification.findByIdAndUpdate(id, { read: true });
    res.json({ success: true });
  } catch (error) {
    console.error("Error marking notification read:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// POST /api/notifications
// Save a triggered notification log
router.post("/", async (req, res) => {
  try {
    const { userId, message, type } = req.body;
    if (!userId || !message) {
      return res.status(400).json({ error: "userId and message are required" });
    }

    const notification = new Notification({
      userId,
      message,
      type: type || "reminder",
      read: false
    });

    await notification.save();
    console.log(`[Route Notifications] Logged triggered notification for user: ${userId} - ${message}`);
    res.status(201).json(notification);
  } catch (error) {
    console.error("Error creating notification log:", error);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
