const express = require("express");
const MealLog = require("../models/MealLog");
const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const history = await MealLog.find({ userId }).sort({ date: -1 });
    res.json(history);
  } catch (error) {
    console.error("Error fetching history:", error);
    res.status(500).json({ error: "Server error" });
  }
});

router.delete("/", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const result = await MealLog.deleteMany({ userId });
    res.json({ message: "History cleared successfully", deletedCount: result.deletedCount });
  } catch (error) {
    console.error("Error clearing history:", error);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
