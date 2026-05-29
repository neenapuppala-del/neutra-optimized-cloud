const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || "your_super_secret_jwt_key_here";

// POST /api/auth/register
router.post("/register", async (req, res) => {
  try {
    const { email, password, name, age, weight, height, gender } = req.body;

    if (!email || !password || !name) {
      return res.status(400).json({ error: "Email, password, and name are required." });
    }

    // 1. Gmail validation: check if email ends with @gmail.com
    if (!email.toLowerCase().endsWith("@gmail.com")) {
      return res.status(400).json({ error: "Email must be a valid @gmail.com address." });
    }

    // 2. Username uniqueness check: check if the username (name) is already taken
    const existingName = await User.findOne({ name: { $regex: new RegExp("^" + name + "$", "i") } });
    if (existingName) {
      return res.status(400).json({ error: "Username is already taken." });
    }
    // Generate a unique userId
    const userId = "usr_" + Date.now().toString() + Math.random().toString(36).substr(2, 5);

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = new User({
      userId,
      email: email.toLowerCase(),
      password: hashedPassword,
      name,
      age: age || undefined,
      weight: weight || undefined,
      height: height || undefined,
      gender: gender || undefined,
    });

    await user.save();

    // Create JWT
    const payload = {
      user: {
        id: user.userId,
      },
    };

    jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" }, (err, token) => {
      if (err) throw err;
      res.status(201).json({ token, user });
    });
  } catch (error) {
    console.error("Error during registration:", error.message);
    res.status(500).json({ error: "Server error" });
  }
});

// POST /api/auth/login
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: "Email/Username and password are required." });
    }

    // Check if user exists by email, username (name), or userId (all case-insensitive for username/email)
    const user = await User.findOne({
      $or: [
        { email: email.toLowerCase() },
        { name: { $regex: new RegExp("^" + email + "$", "i") } },
        { userId: email }
      ]
    });

    if (!user) {
      return res.status(400).json({ error: "Invalid Credentials" });
    }

    // Validate password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: "Invalid Credentials" });
    }

    // Create JWT
    const payload = {
      user: {
        id: user.userId,
      },
    };

    jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" }, (err, token) => {
      if (err) throw err;
      res.json({ token, user });
    });
  } catch (error) {
    console.error("Error during login:", error.message);
    res.status(500).json({ error: "Server error" });
  }
});

// Middleware to protect routes (optional, can be moved to a separate file)
const authMiddleware = (req, res, next) => {
  const token = req.header("x-auth-token");

  if (!token) {
    return res.status(401).json({ error: "No token, authorization denied" });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded.user;
    next();
  } catch (err) {
    res.status(401).json({ error: "Token is not valid" });
  }
};

module.exports = { router, authMiddleware };
