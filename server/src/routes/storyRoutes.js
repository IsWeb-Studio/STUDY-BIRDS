const router = require('express').Router();
const mongoose = require('mongoose');
const { rateLimit } = require('express-rate-limit');
const { protect, authorize } = require('../middleware/authMiddleware');
const asyncHandler = require('../utils/asyncHandler');
const { Story, StoryStats, StoryInteraction } = require('../models/Stories');
const rules = require('../utils/storyRules');
const upload = require('../middleware/uploadMiddleware');
const { uploadFileToCloudinary } = require('../utils/uploadToCloudinary');
const { canReadStory } = require('../utils/storyAudience');
const User = require('../models/User');
const StoryVideo = require('../models/StoryVideo');
const { parseVideo, validateVideo, uploadStoryVideo } = require('../utils/storyVideoUpload');
router.use(protect, authorize('student'));
router.use((req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });
router.use(rateLimit({ windowMs: 60000, limit: 120, keyGenerator: req => String(req.user._id), standardHeaders: 'draft-7', legacyHeaders: false }));
const fail = (status, message) => { throw Object.assign(new Error(message), { statusCode: status }); };
// Transactions make story/edge creation and both balances commit together. MongoDB replica set required.
async function atomic(fn) {
  for (let attempt = 0; ; attempt++) {
    const session = await mongoose.startSession();
    try { let result; await session.withTransaction(async () => { result = await fn(session); }); return result; }
    catch (error) { if (error.code !== 11000 || attempt >= 3) throw error; }
    finally { await session.endSession(); }
  }
}
const statsFor = (user, session) => StoryStats.findOneAndUpdate({ user }, { $setOnInsert: { user } }, { upsert: true, new: true, session, setDefaultsOnInsert: true });
router.get('/progress', asyncHandler(async (req, res) => {
  // Persist lazy expiry with a conditional update so it cannot overwrite a concurrent post.
  await StoryStats.updateOne({ user: req.user._id, lastStoryAt: { $lte: new Date(Date.now() - 36 * rules.HOUR) }, streak_days: { $gt: 0 } }, { $set: { streak_days: 0 } });
  res.json(rules.progress(await StoryStats.findOne({ user: req.user._id }).lean() || {}));
}));
router.put('/preferences', asyncHandler(async (req, res) => {
  const emoji = req.body?.scoreEmoji;
  if (!rules.SCORE_EMOJIS.includes(emoji)) fail(400, 'Invalid score emoji');
  // Only the cosmetic preference can change here; never accept balances from a client.
  const stats = await StoryStats.findOneAndUpdate({ user: req.user._id },
    { $set: { scoreEmoji: emoji } }, { upsert: true, new: true, runValidators: true });
  res.json(rules.progress(stats));
}));
// Small uncached snapshot for active screens; never reload images or the full feed.
router.get('/updates', asyncHandler(async (req, res) => {
  const ids = typeof req.query.ids === 'string' ? [...new Set(req.query.ids.split(','))] : [];
  if (!ids.length || ids.length > 120 || ids.some(id => !/^[a-f0-9]{24}$/i.test(id))) fail(400, 'Invalid stories');
  const stories = await Story.find({ _id: { $in: ids }, expiresAt: { $gt: new Date() } }).select('_id author loveCount')
    .populate({ path: 'author', select: '_id', match: { isActive: true, role: 'student' } }).lean();
  const readable = stories.filter(s => s.author);
  const edges = await StoryInteraction.find({ story: { $in: readable.map(s => s._id) }, user: req.user._id }).select('story lovedAt seenAt').lean();
  const byId = new Map(edges.map(e => [String(e.story), e]));
  const stats = await StoryStats.findOne({ user: req.user._id }).lean();
  res.json({ progress: rules.progress(stats || {}), updates: readable.map(s => ({
    id: String(s._id), loveCount: s.loveCount,
    loved: !!byId.get(String(s._id))?.lovedAt, seen: !!byId.get(String(s._id))?.seenAt,
  })) });
}));
router.get('/', asyncHandler(async (req, res) => {
  const filter = { expiresAt: { $gt: new Date() } };
  if (req.query.before) {
    if (!/^[a-f0-9]{24}$/i.test(req.query.before)) fail(400, 'Invalid cursor');
    filter._id = { $lt: new mongoose.Types.ObjectId(req.query.before) };
  }
  const rows = await Story.aggregate([
    { $match: filter }, { $sort: { _id: -1 } },
    { $lookup: { from: User.collection.name, localField: 'author', foreignField: '_id',
      pipeline: [{ $match: { isActive: true, role: 'student' } }, { $project: { name: 1, avatar: 1 } }], as: 'author' } },
    { $unwind: '$author' }, { $limit: 61 },
  ]);
  const page = rows.slice(0, 60);
  const [edges, stats] = await Promise.all([
    StoryInteraction.find({ story: { $in: page.map(s => s._id) }, user: req.user._id }).select('story seenAt lovedAt').lean(),
    StoryStats.find({ user: { $in: page.map(s => s.author._id) } }).select('user total_points').lean(),
  ]);
  const balances = new Map(stats.map(s => [String(s.user), s.total_points]));
  const interactions = new Map(edges.map(e => [String(e.story), e]));
  res.json({ stories: page.filter(s => s.author).map(s => ({
    id: String(s._id), text: s.text, imageUrl: s.imageUrl, videoUrl: s.videoUrl || '', videoDuration: s.videoDuration || 0, createdAt: s.createdAt, expiresAt: s.expiresAt,
    loveCount: s.loveCount, seen: !!interactions.get(String(s._id))?.seenAt,
    loved: !!interactions.get(String(s._id))?.lovedAt,
    author: { id: String(s.author._id), name: s.author.name, avatar: s.author.avatar || '', total_points: balances.get(String(s.author._id)) || 0 },
  })), nextCursor: rows.length > 60 ? String(page.at(-1)._id) : null });
}));
router.post('/image', rateLimit({ windowMs: 3600000, limit: 20, keyGenerator: req => String(req.user._id) }), upload.single('file'), asyncHandler(async (req, res) => {
  if (!req.file || !['image/jpeg', 'image/png', 'image/webp'].includes(req.file.mimetype)) fail(415, 'Unsupported file type');
  const media = await uploadFileToCloudinary(req.file, `story-images/${req.user._id}`);
  res.json({ imageUrl: media.url });
}));
router.post('/video', rateLimit({ windowMs: 3600000, limit: 10, keyGenerator: req => String(req.user._id) }), parseVideo, asyncHandler(async (req, res) => {
  validateVideo(req.file);
  const media = await uploadStoryVideo(req.file, req.user._id);
  await StoryVideo.create({ owner: req.user._id, url: media.videoUrl, duration: media.duration, expiresAt: new Date(Date.now() + 86400000) });
  res.json(media);
}));
router.post('/', rateLimit({ windowMs: 3600000, limit: 20, keyGenerator: req => String(req.user._id) }), asyncHandler(async (req, res) => {
  const { text = '', imageUrl = '', videoUrl = '', operationId } = req.body || {};
  if (typeof operationId !== 'string' || !/^[A-Za-z0-9-]{8,100}$/.test(operationId) || typeof text !== 'string' || text.length > 1000 || typeof imageUrl !== 'string' || typeof videoUrl !== 'string' || (imageUrl && videoUrl) || (!text.trim() && !imageUrl && !videoUrl)) fail(400, 'Invalid story');
  if (imageUrl) {
    // Only accept this student's own uploaded Cloudinary images, never arbitrary URLs.
    let url; try { url = new URL(imageUrl); } catch { fail(400, 'Invalid image'); }
    if (url.protocol !== 'https:' || url.hostname !== 'res.cloudinary.com' || !url.pathname.startsWith(`/${process.env.CLOUDINARY_CLOUD_NAME}/image/upload/`) || !url.pathname.includes(`/story-images/${req.user._id}/`)) fail(400, 'Invalid image');
  }
  const result = await atomic(async session => {
    const now = Date.now();
    const existing = await Story.findOne({ author: req.user._id, operationId }).session(session);
    if (existing) return { id: existing.id, progress: rules.progress(await statsFor(req.user._id, session), now), awarded: 0 };
    const video = videoUrl ? await StoryVideo.findOne({ owner: req.user._id, url: videoUrl, expiresAt: { $gt: new Date(now) } }).session(session) : null;
    if (videoUrl && !video) fail(400, 'Upload your own video first');
    const stats = await statsFor(req.user._id, session);
    const awarded = rules.postReward(stats, now);
    await stats.save({ session });
    const [story] = await Story.create([{ author: req.user._id, operationId, text: text.trim(), imageUrl, videoUrl,
      videoDuration: video?.duration || 0, expiresAt: new Date(now + 24 * rules.HOUR) }], { session });
    return { id: story.id, progress: rules.progress(stats, now), awarded };
  });
  res.status(201).json(result);
}));
router.param('id', (req, res, next, id) => /^[a-f0-9]{24}$/i.test(id) ? next() : res.status(400).json({ message: 'Invalid story' }));
router.post('/:id/seen', asyncHandler(async (req, res) => {
  const story = await Story.findOne({ _id: req.params.id, expiresAt: { $gt: new Date() } }).select('author').lean();
  if (!story || !await canReadStory(req.user._id, story.author)) fail(404, 'Story unavailable');
  const filter = { story: req.params.id, user: req.user._id };
  const update = { $set: { seenAt: new Date() } };
  try { await StoryInteraction.updateOne(filter, update, { upsert: true }); }
  catch (error) {
    // A simultaneous first view/love may have just inserted this unique edge.
    if (error.code !== 11000) throw error;
    await StoryInteraction.updateOne(filter, update);
  }
  res.json({ seen: true });
}));
router.post('/:id/love', asyncHandler(async (req, res) => {
  const result = await atomic(async session => {
    const now = Date.now();
    const story = await Story.findOne({ _id: req.params.id, expiresAt: { $gt: new Date(now) } }).session(session);
    if (!story) fail(404, 'Story expired');
    if (!await canReadStory(req.user._id, story.author, session)) fail(404, 'Story unavailable');
    if (String(story.author) === String(req.user._id)) fail(403, 'Cannot love your own story');
    const edge = await StoryInteraction.findOneAndUpdate({ story: story._id, user: req.user._id }, { $setOnInsert: { story: story._id, user: req.user._id } }, { upsert: true, new: true, session });
    const giver = await statsFor(req.user._id, session);
    if (edge.lovedAt) return { loved: true, loveCount: story.loveCount, awarded: 0, progress: rules.progress(giver, now) };
    edge.lovedAt = new Date(now); await edge.save({ session });
    const owner = await statsFor(story.author, session);
    owner.total_points += 50; await owner.save({ session });
    const awarded = rules.loveReward(giver, now); await giver.save({ session });
    story.loveCount++; await story.save({ session });
    return { loved: true, loveCount: story.loveCount, awarded, progress: rules.progress(giver, now) };
  });
  res.json(result);
}));
module.exports = router;
