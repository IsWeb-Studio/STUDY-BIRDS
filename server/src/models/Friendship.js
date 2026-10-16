const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  _id: { type: String }, // Sorted user ids: one relationship in either direction.
  requester: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  status: { type: String, enum: ['pending', 'accepted'], default: 'pending' },
}, { timestamps: true });
schema.index({ requester: 1, status: 1 });
schema.index({ recipient: 1, status: 1 });
schema.statics.pair = (a, b) => [String(a).toLowerCase(), String(b).toLowerCase()].sort().join(':');
module.exports = mongoose.model('Friendship', schema);
