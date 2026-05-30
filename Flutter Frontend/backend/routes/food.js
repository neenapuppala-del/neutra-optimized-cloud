const express = require("express");
const multer = require("multer");
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");

const User = require("../models/User");

const router = express.Router();

const storage = multer.memoryStorage();

const upload = multer({ storage: storage });

const PYTHON_API = process.env.PYTHON_API_URL || "https://neutra-optimized-cloud.onrender.com/api";

// Proxy scan to Python phase1
router.post("/scan", upload.array("files"), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: "No image provided" });
    }

    console.log(`Received ${req.files.length} image(s) from Flutter`);

    const form = new FormData();
    req.files.forEach((file) => {
      form.append("files", file.buffer, {
        filename: file.originalname,
        contentType: file.mimetype,
      });
    });

    const response = await axios.post(`${PYTHON_API}/phase1/detect`, form, {
      headers: {
        ...form.getHeaders(),
      },
      maxContentLength: Infinity,
      maxBodyLength: Infinity,
    });

    const dishes = response.data.detected_dishes.map(d => d.name).join(", ");
    console.log(`Meal name(s) retrieved from RAG: ${dishes}`);

    res.json(response.data);
  } catch (error) {
    console.error("Error connecting to Python backend (Phase 1):", error.message);
    res.status(500).json({ error: "Phase 1 detection failed" });
  }
});

// Proxy nutrition to Python phase2
router.post("/nutrition", async (req, res) => {
  try {
    console.log("Received nutrition payload in Node:", req.body);
    
    let payload = { ...req.body };
    
    // Inject user profile if userId is provided
    if (payload.userId) {
      const user = await User.findOne({ userId: payload.userId });
      if (user) {
        payload.user_profile = {
          name: user.name,
          age: user.age,
          weight: user.weight,
          height: user.height,
          gender: user.gender,
          health_issues: user.health_issues,
          goals: user.goals,
          dietary_preferences: user.dietary_preferences,
          target_weight: user.target_weight,
        };
        console.log("Injected user_profile into Phase 2 payload:", payload.user_profile);
      }
      // Remove userId before sending to Python if necessary, or leave it.
      // Python expects 'user_profile: Optional[Dict]' in Phase2Request.
    }

    const response = await axios.post(`${PYTHON_API}/phase2/nutrition`, payload);

    // We already have MongoDB saving logic in main.py, but we can also save it here if needed.
    // For now, since Python handles saving in its DB, we just proxy the result back.

    res.json(response.data);
  } catch (error) {
    console.error("Error connecting to Python backend (Phase 2):", error.response ? error.response.data : error.message);
    res.status(500).json({ error: "Phase 2 calculation failed", details: error.response ? error.response.data : error.message });
  }
});

module.exports = router;