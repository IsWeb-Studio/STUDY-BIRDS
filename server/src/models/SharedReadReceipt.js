const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  resource: { type: String, required: true },
  entity: { type: mongoose.Schema.Types.ObjectId, required: true },
  revision: { type: String, required: true },
  readAt: { type: Date, required: true },
  readBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { versionKey: false });
schema.index({ resource: 1, entity: 1 }, { unique: true });
module.exports = mongoose.model('SharedReadReceipt', schema);
