const mongoose = require('mongoose');
const { Schema } = mongoose;
const storySchema = new Schema({
  author: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  operationId: { type: String, required: true },
  text: { type: String, maxlength: 1000, default: '' },
  audience: { type: String, enum: ['students', 'guardians', 'universities', 'employees', 'allEligible'], default: 'allEligible' },
  imageUrl: { type: String, default: '' },
  videoUrl: { type: String, default: '' },
  videoDuration: { type: Number, default: 0 },
  mediaCleanupQueued: Boolean,
  deletedAt: Date,
  loveCount: { type: Number, default: 0 },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });
storySchema.index({ author: 1, operationId: 1 }, { unique: true });
storySchema.index({ expiresAt: 1, _id: -1 });
// Keep records for durable replay protection; expiry is enforced on every read/write.
const statsSchema = new Schema({
  user: { type: Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  total_points: { type: Number, default: 0 },
  scoreEmoji: { type: String, enum: require('../utils/storyRules').SCORE_EMOJIS, default: '🔥' },
  streak_days: { type: Number, default: 0 },
  brokenStreakDays: { type: Number, default: 0 },
  streakRestoreMonth: String,
  streakRestoresUsed: { type: Number, default: 0 },
  lastStoryAt: Date,
  lastPostDay: String,
  dailyGameDay: String,
  dailyLoveDay: String,
  dailyLoveCount: { type: Number, default: 0 },
});
const interactionSchema = new Schema({
  story: { type: Schema.Types.ObjectId, required: true },
  user: { type: Schema.Types.ObjectId, required: true },
  seenAt: Date,
  lovedAt: Date,
});
interactionSchema.index({ story: 1, user: 1 }, { unique: true });
interactionSchema.index({ story: 1, _id: -1 });
module.exports = {
  Story: mongoose.model('Story', storySchema),
  StoryStats: mongoose.model('StoryStats', statsSchema),
  StoryInteraction: mongoose.model('StoryInteraction', interactionSchema),
};
