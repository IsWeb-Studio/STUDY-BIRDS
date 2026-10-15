const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  code: { type: String, unique: true, required: true },
  revision: { type: Number, default: 0 },
  state: { type: mongoose.Schema.Types.Mixed, required: true, select: false },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });
schema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
schema.index({ 'state.players.id': 1 });
module.exports = mongoose.model('WinkRoom', schema);
