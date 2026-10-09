const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  to: { type: String, required: true },
  subject: { type: String, required: true },
  text: String,
  emailContent: mongoose.Schema.Types.Mixed,
  status: { type: String, enum: ['pending', 'sending', 'sent'], default: 'pending' },
  attempts: { type: Number, default: 0 },
  nextAttemptAt: { type: Date, default: Date.now },
  lockedUntil: Date,
  sentAt: Date,
}, { timestamps: true });
schema.index({ status: 1, nextAttemptAt: 1 });
module.exports = mongoose.model('EmailDelivery', schema);
