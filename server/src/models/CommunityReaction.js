const mongoose = require('mongoose');
const REACTIONS = ['love', 'like', 'hundred', 'laugh', 'wow', 'trophy', 'clap'];
const schema = new mongoose.Schema({
  post: { type: mongoose.Schema.Types.ObjectId, ref: 'CommunityPost', required: true, index: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  reaction: { type: String, enum: REACTIONS, required: true },
}, { timestamps: true });
schema.index({ post: 1, user: 1 }, { unique: true });
module.exports = mongoose.model('CommunityReaction', schema);
module.exports.REACTIONS = REACTIONS;
