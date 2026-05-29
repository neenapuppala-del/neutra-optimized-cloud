const express = require("express");
const MealLog = require("../models/MealLog");
const User = require("../models/User");
const router = express.Router();

// Helper to find a nutrient value using a case-insensitive match from the keys list
const getNutrientVal = (nuts, possibleKeys) => {
  for (const k of Object.keys(nuts)) {
    const lowerK = k.toLowerCase();
    if (possibleKeys.some(pk => lowerK.includes(pk))) {
      const val = nuts[k];
      if (val == null) continue;
      if (typeof val === 'number') return val;
      const parsed = parseFloat(val.toString().replace(/[^0-9.]/g, ''));
      return isNaN(parsed) ? 0 : parsed;
    }
  }
  return 0;
};

router.get("/daily", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const offset = parseInt(req.query.timezoneOffset) || 0;
    const nowUtc = new Date();
    const localNow = new Date(nowUtc.getTime() + offset * 60000);
    localNow.setUTCHours(0, 0, 0, 0);
    const startOfDay = new Date(localNow.getTime() - offset * 60000);
    const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000 - 1);

    const meals = await MealLog.find({
      userId,
      date: { $gte: startOfDay, $lte: endOfDay },
    });

    let totalScore = 0;
    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFats = 0;

    meals.forEach(meal => {
      totalScore += meal.healthScore;
      const nuts = meal.nutrients || {};
      totalCalories += getNutrientVal(nuts, ["calor", "energy", "kcal"]);
      totalProtein += getNutrientVal(nuts, ["protein", "prot"]);
      totalCarbs += getNutrientVal(nuts, ["carbohydrate", "carb"]);
      totalFats += getNutrientVal(nuts, ["fat"]);
    });

    const averageScore = meals.length > 0 ? Math.round(totalScore / meals.length) : 0;

    res.json({
      averageScore,
      meals,
      totalCalories: Math.round(totalCalories),
      totalProtein: Math.round(totalProtein),
      totalCarbs: Math.round(totalCarbs),
      totalFats: Math.round(totalFats),
    });
  } catch (error) {
    console.error("Error fetching daily stats:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Endpoint for saving a meal log
router.post("/log", async (req, res) => {
  try {
    const { userId, dishName, healthScore, nutrients } = req.body;
    if (!userId || !dishName || healthScore == null) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const meal = new MealLog({
      userId,
      dishName,
      healthScore,
      nutrients: nutrients || {},
    });
    await meal.save();

    res.json({ success: true, meal });
  } catch (error) {
    console.error("Error saving meal:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Daily review
router.get("/daily-review", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const user = await User.findOne({ userId });
    
    const offset = parseInt(req.query.timezoneOffset) || 0;
    const nowUtc = new Date();
    const localNow = new Date(nowUtc.getTime() + offset * 60000);
    localNow.setUTCHours(0, 0, 0, 0);
    const startOfDay = new Date(localNow.getTime() - offset * 60000);
    const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000 - 1);
    
    const meals = await MealLog.find({
      userId,
      date: { $gte: startOfDay, $lte: endOfDay },
    });

    let totalScore = 0;
    meals.forEach(meal => totalScore += meal.healthScore);
    const averageScore = meals.length > 0 ? Math.round(totalScore / meals.length) : 0;

    let review = "";
    if (averageScore >= 80) {
      review = "Excellent job today! You maintained a high health score.";
    } else if (averageScore >= 50) {
      review = "Good job today, but there's room for improvement in nutrient balance.";
    } else if (meals.length == 0) {
      review = "You haven't logged any meals today. Start logging to get insights!";
    } else {
      review = "Your average health score is low today. Consider choosing healthier options tomorrow.";
    }

    if (user && user.goals && user.goals.includes("Weight Loss")) {
      review += " Keep an eye on portion sizes to stay aligned with your Weight Loss goal.";
    }

    res.json({ review, averageScore });
  } catch (error) {
    console.error("Error generating review:", error);
    res.status(500).json({ error: "Server error" });
  }
});

// Weekly Analytics
router.get("/weekly", async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    const offset = parseInt(req.query.timezoneOffset) || 0;
    const nowUtc = new Date();
    const localNow = new Date(nowUtc.getTime() + offset * 60000);
    localNow.setUTCHours(0, 0, 0, 0);
    
    const startOfTodayUtc = new Date(localNow.getTime() - offset * 60000);
    const endOfToday = new Date(startOfTodayUtc.getTime() + 24 * 60 * 60 * 1000 - 1);
    const startOf7DaysAgo = new Date(startOfTodayUtc.getTime() - 6 * 24 * 60 * 60 * 1000);

    const meals = await MealLog.find({
      userId,
      date: { $gte: startOf7DaysAgo, $lte: endOfToday },
    });

    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFats = 0;
    
    // Arrays for charts (Mon-Sun like, but here we just use last 7 days)
    // Initialize array for the last 7 days
    const daysArr = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const todayIndex = new Date().getDay() === 0 ? 6 : new Date().getDay() - 1; // 0 for Mon, 6 for Sun
    
    let weeklyCalories = [0, 0, 0, 0, 0, 0, 0];
    let proteinTrend = [0, 0, 0, 0, 0, 0, 0];
    let daysLoggedSet = new Set();

    meals.forEach(meal => {
      // Calculate day of week index (0 = Mon, 6 = Sun) based on user's local time
      const localMealTime = new Date(meal.date.getTime() + offset * 60000);
      let dayIndex = localMealTime.getUTCDay() === 0 ? 6 : localMealTime.getUTCDay() - 1;
      
      const dateString = localMealTime.toISOString().split('T')[0];
      daysLoggedSet.add(dateString);

      const nuts = meal.nutrients || {};

      const cals = getNutrientVal(nuts, ["calor", "energy", "kcal"]);
      const prot = getNutrientVal(nuts, ["protein", "prot"]);
      const carbs = getNutrientVal(nuts, ["carbohydrate", "carb"]);
      const fats = getNutrientVal(nuts, ["fat"]);

      totalCalories += cals;
      totalProtein += prot;
      totalCarbs += carbs;
      totalFats += fats;

      weeklyCalories[dayIndex] += cals;
      proteinTrend[dayIndex] += prot;
    });

    const daysLoggedThisWeek = daysLoggedSet.size;
    const avgDailyCalories = daysLoggedThisWeek > 0 ? Math.round(totalCalories / daysLoggedThisWeek) : 0;
    const proteinAvg = daysLoggedThisWeek > 0 ? Math.round(totalProtein / daysLoggedThisWeek) : 0;
    
    const totalMacros = totalProtein + totalCarbs + totalFats;
    const macroDistribution = {
      protein: totalMacros > 0 ? Math.round((totalProtein / totalMacros) * 100) : 0,
      carbs: totalMacros > 0 ? Math.round((totalCarbs / totalMacros) * 100) : 0,
      fats: totalMacros > 0 ? Math.round((totalFats / totalMacros) * 100) : 0,
    };

    // Round the trend arrays to return only integers and avoid Dart type crashes
    const roundedWeeklyCalories = weeklyCalories.map(Math.round);
    const roundedProteinTrend = proteinTrend.map(Math.round);

    res.json({
      avgDailyCalories,
      daysLoggedThisWeek,
      proteinAvg,
      macroDistribution,
      proteinTrend: roundedProteinTrend,
      weeklyCalories: roundedWeeklyCalories,
    });
  } catch (error) {
    console.error("Error fetching weekly stats:", error);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
