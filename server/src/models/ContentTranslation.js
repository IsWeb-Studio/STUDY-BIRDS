const mongoose = require("mongoose");

// Cache of machine translations of catalog content, keyed by source-text hash.
const contentTranslationSchema = new mongoose.Schema(
  {
    hash: { type: String, required: true },
    target: { type: String, enum: ["en", "ar"], required: true },
    source: { type: String, required: true },
    text: { type: String, required: true },
  },
  { timestamps: true }
);

contentTranslationSchema.index({ hash: 1, target: 1 }, { unique: true });

module.exports = mongoose.models.ContentTranslation || mongoose.model("ContentTranslation", contentTranslationSchema);
