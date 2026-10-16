const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  contact: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  muted: { type: Boolean, default: false },
  clearedAt: Date,
}, { timestamps: true });
schema.index({ user: 1, contact: 1 }, { unique: true });
module.exports = mongoose.model('ChatPreference', schema);
