const express = require("express");
const User = require("../models/User");

const router = express.Router();

// GET /api/user/profile/:userId
router.get("/profile/:userId", async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId });
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }
    
    // Ensure default notifications exist
    if (!user.custom_notifications || user.custom_notifications.length === 0) {
      user.custom_notifications = [
        { title: "💧 Drink Water", time: "08:00 AM", isOn: false, repeat: "None" },
        { title: "🍽️ Meal Logging", time: "01:00 PM", isOn: false, repeat: "None" },
        { title: "💪 Workout", time: "06:00 PM", isOn: false, repeat: "None" }
      ];
      await user.save();
      console.log(`[Route User] Pre-populated default notifications for user: ${user.userId}`);
    }

    res.json(user);
  } catch (error) {
    console.error("Error fetching user profile:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// POST /api/user/profile
// Create or update a user profile
router.post("/profile", async (req, res) => {
  try {
    const { userId, theme, name, age, weight, height, gender, goals, target_weight, health_issues, dietary_preferences, notifications, user_profile } = req.body;

    if (!userId) {
      return res.status(400).json({ error: "userId is required" });
    }

    let user = await User.findOne({ userId });
    
    if (user) {
      // Update existing - only update fields if they are explicitly passed (not undefined)
      if (name !== undefined) user.name = name;
      if (age !== undefined) user.age = age;
      if (weight !== undefined) user.weight = weight;
      if (height !== undefined) user.height = height;
      if (gender !== undefined) user.gender = gender;
      if (goals !== undefined) user.goals = goals;
      if (target_weight !== undefined) user.target_weight = target_weight;
      if (health_issues !== undefined) user.health_issues = health_issues;
      if (dietary_preferences !== undefined) user.dietary_preferences = dietary_preferences;
      if (notifications !== undefined) user.notifications = notifications;
      if (theme !== undefined) user.theme = theme;
      if (user_profile !== undefined) user.user_profile = user_profile;
      
      await user.save();
      return res.json({ message: "Profile updated successfully", user });
    } else {
      // Create new
      if (!name) {
        return res.status(400).json({ error: "name is required to create a profile" });
      }
      user = new User({
        userId,
        name,
        age,
        weight,
        height,
        gender,
        goals: goals || [],
        target_weight: target_weight,
        health_issues: health_issues || [],
        dietary_preferences: dietary_preferences || [],
        notifications: notifications || { water: false, meal: false, workout: false },
        theme: theme || "light",
        user_profile: user_profile || "https://cdn-icons-png.flaticon.com/512/149/149071.png",
      });
      await user.save();
      return res.status(201).json({ message: "Profile created successfully", user });
    }
  } catch (error) {
    console.error("Error saving user profile:", error);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
