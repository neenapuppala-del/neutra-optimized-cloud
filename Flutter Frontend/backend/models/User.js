const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
    },
    email: {
      type: String,
      required: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    age: {
      type: Number,
    },
    weight: {
      type: Number, // in kg
    },
    height: {
      type: Number, // in cm
    },
    gender: {
      type: String,
    },
    target_weight: {
      type: Number,
    },
    goals: {
      type: [String],
      default: [],
    },
    health_issues: {
      type: [String],
      default: [],
    },
    dietary_preferences: {
      type: [String],
      default: [],
    },
    notifications: {
      type: Object,
      default: {
        water: false,
        meal: false,
        workout: false
      }
    },
    custom_notifications: {
      type: [
        {
          title: String,
          time: String,
          isOn: Boolean,
          repeat: { type: String, default: "None" }
        }
      ],
      default: [
        { title: "💧 Drink Water", time: "08:00 AM", isOn: false, repeat: "None" },
        { title: "🍽️ Meal Logging", time: "01:00 PM", isOn: false, repeat: "None" },
        { title: "💪 Workout", time: "06:00 PM", isOn: false, repeat: "None" }
      ]
    },
    theme: {
      type: String,
      enum: ["light", "dark"],
      default: "light"
    },
    user_profile: {
      type: String,
      default: "https://cdn-icons-png.flaticon.com/512/149/149071.png"
    }
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("User", UserSchema);
