const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  requestId: { type: String, required: true },
  title: { type: String, required: true },
  body: { type: String, required: true },
  status: { type: String, enum: ['pending', 'accepted', 'no_subscribers', 'uncertain'], default: 'pending' },
  providerId: String,
}, { timestamps: true });
schema.index({ createdBy: 1, requestId: 1 }, { unique: true });
module.exports = mongoose.model('PushAnnouncement', schema);
