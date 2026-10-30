const mongoose = require('mongoose');

// Kept only until cleanup succeeds. No password, token or document content.
module.exports = mongoose.model('AccountDeletionJob', new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, required: true, unique: true },
  email: String,
  state: { type: String, enum: ['pending', 'complete'], default: 'pending' },
  attempts: { type: Number, default: 0 },
  lockedUntil: { type: Date, default: () => new Date(0) },
  snapshot: mongoose.Schema.Types.Mixed,
}, { timestamps: true }));
