const express = require("express");
const User = require("../models/User");

const router = express.Router();

// Add a custom notification
router.post("/", async (req, res) => {
  try {
    const { userId, title, time, isOn, repeat } = req.body;

    if (!userId || !title || !time) {
      return res.status(400).json({ error: "userId, title, and time are required" });
    }

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    user.custom_notifications.push({
      title,
      time,
      isOn: isOn !== undefined ? isOn : true,
      repeat: repeat || "None"
    });

    await user.save();
    res.json({ message: "Custom notification added successfully", custom_notifications: user.custom_notifications });
  } catch (error) {
    console.error("Error setting custom notification:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Toggle or update a custom notification
router.put("/:id", async (req, res) => {
  try {
    const userId = req.body.userId || req.query.userId;
    const { isOn, title, time, repeat } = req.body;
    const notificationId = req.params.id;

    if (!userId) {
      return res.status(400).json({ error: "userId is required" });
    }

    if (!/^[0-9a-fA-F]{24}$/.test(notificationId)) {
      return res.status(400).json({ error: "Invalid notification ID format" });
    }

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    const notif = user.custom_notifications.id(notificationId);
    if (!notif) {
       return res.status(404).json({ error: "Notification not found" });
    }

    if (isOn !== undefined) notif.isOn = isOn;
    if (title !== undefined) notif.title = title;
    if (time !== undefined) notif.time = time;
    if (repeat !== undefined) notif.repeat = repeat;

    await user.save();
    res.json({ message: "Custom notification updated", custom_notifications: user.custom_notifications });
  } catch (error) {
    console.error("Error updating custom notification:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Delete a custom notification
router.delete("/:id", async (req, res) => {
  try {
    const userId = req.body.userId || req.query.userId;
    const notificationId = req.params.id;

    if (!userId) {
      return res.status(400).json({ error: "userId is required" });
    }

    if (!/^[0-9a-fA-F]{24}$/.test(notificationId)) {
      return res.status(400).json({ error: "Invalid notification ID format" });
    }

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    user.custom_notifications = user.custom_notifications.filter(
      (n) => n._id && n._id.toString() !== notificationId
    );

    await user.save();
    res.json({ message: "Custom notification deleted successfully", custom_notifications: user.custom_notifications });
  } catch (error) {
    console.error("Error deleting custom notification:", error);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
