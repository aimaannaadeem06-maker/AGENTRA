// routes/chatbot.route.js
const express = require("express");
const router = express.Router();
const { chat, initializeRAG } = require("../controllers/chatbot.controller");
// ADD THIS TEST ROUTE
router.get("/test-packages", async (req, res) => {
  const Package = require("../models/Package");
  const packages = await Package.find({ location: /murree/i }).limit(5).lean();
  res.json({ count: packages.length, packages });
});

router.post("/init", initializeRAG); // Manually re-trigger RAG init if needed
router.post("/chat", chat);          // Main chat endpoint

module.exports = router;
