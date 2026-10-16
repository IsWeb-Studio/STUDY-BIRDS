const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  owner: { type: mongoose.Schema.Types.ObjectId, required: true },
  url: { type: String, required: true },
  duration: { type: Number, required: true, min: 0.01, max: 60 },
  expiresAt: { type: Date, required: true },
});
schema.index({ owner: 1, url: 1 });
schema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
module.exports = mongoose.model('StoryVideo', schema);
