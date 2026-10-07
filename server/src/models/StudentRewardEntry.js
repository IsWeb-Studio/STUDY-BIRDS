const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  event: { type: String, required: true },
  source: { type: mongoose.Schema.Types.ObjectId, required: true },
  points: { type: Number, required: true, min: 1, validate: Number.isSafeInteger },
  description: { type: String, required: true },
}, { timestamps: true });
// Changing a rule or retrying reconciliation must never award an event twice.
schema.index({ student: 1, event: 1, source: 1 }, { unique: true });
module.exports = mongoose.model('StudentRewardEntry', schema);
