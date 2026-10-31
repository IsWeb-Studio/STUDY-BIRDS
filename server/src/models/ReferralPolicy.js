const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  scope: { type: String, unique: true, required: true },
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  amount: { type: Number, required: true, min: 0, max: 10000 },
  enabled: { type: Boolean, default: true },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });
module.exports = mongoose.model('ReferralPolicy', schema);
