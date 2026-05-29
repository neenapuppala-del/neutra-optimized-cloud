const mongoose = require("mongoose");

const MealLogSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
    },
    dishName: {
      type: String,
      required: true,
    },
    healthScore: {
      type: Number,
      required: true,
    },
    nutrients: {
      type: Object,
      required: true,
    },
    date: {
      type: Date,
      default: Date.now,
    },
    suggestions: {
      type: [String], // Array of suggestion strings
      default: [],
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("MealLog", MealLogSchema);
