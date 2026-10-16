const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  kind: { type: String, enum: ['media', 'account'], required: true },
  owner: mongoose.Schema.Types.ObjectId,
  publicId: String, resourceType: String, deliveryType: String, url: String,
  dueAt: { type: Date, required: true, default: Date.now },
  attempts: { type: Number, default: 0 },
}, { timestamps: true });
schema.index({ dueAt: 1 });
module.exports = mongoose.model('MaintenanceJob', schema);
