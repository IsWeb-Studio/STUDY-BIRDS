const express = require("express");
const { rateLimit } = require("express-rate-limit");
const asyncHandler = require("../utils/asyncHandler");
const { translateTexts, isConfigured, MAX_TEXT_LENGTH } = require("../utils/contentTranslator");

const router = express.Router();

router.get("/config", (req, res) => res.json({ enabled: isConfigured() }));

router.post(
  "/",
  rateLimit({ windowMs: 60_000, limit: 30, standardHeaders: "draft-7", legacyHeaders: false }),
  asyncHandler(async (req, res) => {
    const target = req.body?.target === "ar" ? "ar" : "en";
    const texts = req.body?.texts;
    if (!Array.isArray(texts) || texts.length === 0 || texts.length > 60 || texts.some((item) => typeof item !== "string" || item.length > MAX_TEXT_LENGTH)) {
      res.status(400);
      throw new Error("texts must be 1-60 strings");
    }
    const translations = await translateTexts(texts.map((item) => item.trim()), target);
    res.json({ translations });
  })
);

module.exports = router;
