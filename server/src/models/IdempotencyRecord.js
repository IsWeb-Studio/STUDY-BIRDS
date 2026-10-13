const mongoose = require("mongoose");

// One row per (caller scope, Idempotency-Key). Rows expire by themselves, so a
// client may safely retry a write for 24 hours without ever creating a
// duplicate; after that the key is forgotten.
const idempotencyRecordSchema = new mongoose.Schema(
  {
    scope: { type: String, required: true },
    key: { type: String, required: true },
    fingerprint: { type: String, required: true },
    state: { type: String, enum: ["in_progress", "done"], default: "in_progress" },
    status: Number,
    body: mongoose.Schema.Types.Mixed,
    createdAt: { type: Date, default: Date.now, expires: 60 * 60 * 24 },
  },
  { versionKey: false }
);

idempotencyRecordSchema.index({ scope: 1, key: 1 }, { unique: true });

module.exports = mongoose.model("IdempotencyRecord", idempotencyRecordSchema);
