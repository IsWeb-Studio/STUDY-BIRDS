const router = require('express').Router();
const { rateLimit } = require('express-rate-limit');
const { protect, authorize } = require('../middleware/authMiddleware');
const asyncHandler = require('../utils/asyncHandler');
const Friendship = require('../models/Friendship');
const User = require('../models/User');
const { StoryStats, Story, StoryInteraction } = require('../models/Stories');
const rules = require('../utils/storyRules');
router.use(protect, authorize('student'));
router.use((req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });
router.use(rateLimit({ windowMs: 60000, limit: 100, keyGenerator: req => String(req.user._id), standardHeaders: 'draft-7', legacyHeaders: false }));
const fail = (status, message) => { throw Object.assign(new Error(message), { statusCode: status }); };
function relation(row, id) {
  return !row ? 'none' : row.status === 'accepted' ? 'friends' : String(row.requester) === String(id) ? 'outgoing' : 'incoming';
}
async function people(users, rows, me) {
  const stats = await StoryStats.find({ user: { $in: users.map(u => u._id) } }).select('user total_points').lean();
  const scores = new Map(stats.map(s => [String(s.user), s.total_points]));
  const edges = new Map(rows.map(r => [r._id, r]));
  return users.map(u => ({ id: String(u._id), name: u.name, avatar: u.avatar || '',
    total_points: scores.get(String(u._id)) || 0, relation: relation(edges.get(Friendship.pair(me, u._id)), me) }));
}
router.get('/search', asyncHandler(async (req, res) => {
  const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  if (q.length < 2 || q.length > 60) fail(400, 'Search requires 2 to 60 characters');
  const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const filter = { _id: { $ne: req.user._id }, role: 'student', isActive: true, name: { $regex: escaped, $options: 'i' } };
  if (req.query.before) {
    if (!/^[a-f0-9]{24}$/i.test(req.query.before)) fail(400, 'Invalid cursor');
    filter._id.$lt = req.query.before;
  }
  const rows = await User.find(filter).select('_id name avatar').sort({ _id: -1 }).limit(31).lean();
  const page = rows.slice(0, 30);
  const edges = await Friendship.find({ _id: { $in: page.map(u => Friendship.pair(req.user._id, u._id)) } }).lean();
  res.json({ people: await people(page, edges, req.user._id), nextCursor: rows.length > 30 ? String(page.at(-1)._id) : null });
}));
router.get('/', asyncHandler(async (req, res) => {
  const me = req.user._id;
  const filters = {
    friends: { status: 'accepted', $or: [{ requester: me }, { recipient: me }] },
    incoming: { status: 'pending', recipient: me },
    outgoing: { status: 'pending', requester: me },
  };
  const kind = req.query.kind || 'friends';
  if (!Object.hasOwn(filters, kind)) fail(400, 'Invalid friends list');
  const filter = { ...filters[kind] };
  if (req.query.before) {
    if (!/^[a-f0-9]{24}:[a-f0-9]{24}$/i.test(req.query.before)) fail(400, 'Invalid cursor');
    filter._id = { $lt: req.query.before };
  }
  const rows = await Friendship.find(filter).sort({ _id: -1 }).limit(31).lean();
  const page = rows.slice(0, 30);
  const users = await User.find({ _id: { $in: page.map(r => String(r.requester) === String(me) ? r.recipient : r.requester) }, role: 'student', isActive: true }).select('_id name avatar').lean();
  const byId = new Map(users.map(u => [String(u._id), u]));
  const ordered = page.map(r => byId.get(String(r.requester) === String(me) ? String(r.recipient) : String(r.requester))).filter(Boolean);
  const counts = await Promise.all(Object.values(filters).map(f => Friendship.countDocuments(f)));
  res.json({ people: await people(ordered, page, me), nextCursor: rows.length > 30 ? page.at(-1)._id : null,
    counts: Object.fromEntries(Object.keys(filters).map((k, i) => [k, counts[i]])) });
}));
// A public student profile is deliberately separate from private account/CRM data.
router.get('/:profileId/profile', asyncHandler(async (req, res) => {
  const id = req.params.profileId;
  if (!/^[a-f0-9]{24}$/i.test(id)) fail(400, 'Invalid student');
  if (req.query.before && !/^[a-f0-9]{24}$/i.test(req.query.before)) fail(400, 'Invalid cursor');
  const user = await User.findOne({ _id: id, role: 'student', isActive: true }).select('_id name avatar createdAt').lean();
  if (!user) fail(404, 'Student unavailable');
  const self = String(user._id) === String(req.user._id);
  const edge = self ? null : await Friendship.findById(Friendship.pair(req.user._id, user._id)).lean();
  const relationship = self ? 'self' : relation(edge, req.user._id);
  const canViewStories = true;
  const stats = rules.progress(await StoryStats.findOne({ user: user._id }).lean() || {});
  const friendCount = await Friendship.countDocuments({ status: 'accepted', $or: [{ requester: user._id }, { recipient: user._id }] });
  const filter = { author: user._id, expiresAt: { $gt: new Date() } };
  const storyCount = canViewStories ? await Story.countDocuments(filter) : null;
  if (req.query.before) filter._id = { $lt: req.query.before };
  const rows = canViewStories ? await Story.find(filter).sort({ _id: -1 }).limit(31).lean() : [];
  const page = rows.slice(0, 30);
  const edges = await StoryInteraction.find({ story: { $in: page.map(s => s._id) }, user: req.user._id }).select('story lovedAt seenAt').lean();
  const byStory = new Map(edges.map(e => [String(e.story), e]));
  const author = { id: String(user._id), name: user.name, avatar: user.avatar || '', total_points: stats.total_points };
  res.json({ id: String(user._id), name: user.name, avatar: user.avatar || '', joinedAt: user.createdAt,
    total_points: stats.total_points, streak_days: stats.streak_days, scoreEmoji: stats.scoreEmoji,
    friendCount, relation: relationship, canMessage: !self, canViewStories, storyCount,
    stories: page.map(s => ({ id: String(s._id), author, text: s.text, imageUrl: s.imageUrl || '', videoUrl: s.videoUrl || '',
      videoDuration: s.videoDuration || 0, expiresAt: s.expiresAt, createdAt: s.createdAt, loveCount: s.loveCount,
      loved: !!byStory.get(String(s._id))?.lovedAt, seen: !!byStory.get(String(s._id))?.seenAt })),
    nextStoriesCursor: rows.length > 30 ? String(page.at(-1)._id) : null });
}));
router.param('userId', (req, res, next, id) => /^[a-f0-9]{24}$/i.test(id) && id.toLowerCase() !== String(req.user._id) ? next() : res.status(400).json({ message: 'Invalid student' }));
router.post('/:userId/request', rateLimit({ windowMs: 86400000, limit: 50, keyGenerator: req => String(req.user._id) }), asyncHandler(async (req, res) => {
  if (!await User.exists({ _id: req.params.userId, role: 'student', isActive: true })) fail(404, 'Student unavailable');
  const id = Friendship.pair(req.user._id, req.params.userId);
  let row;
  try { row = await Friendship.findOneAndUpdate({ _id: id }, { $setOnInsert: { requester: req.user._id, recipient: req.params.userId, status: 'pending' } }, { upsert: true, new: true }); }
  catch (error) { if (error.code !== 11000) throw error; row = await Friendship.findById(id); }
  res.json({ relation: relation(row, req.user._id) });
}));
router.post('/:userId/accept', asyncHandler(async (req, res) => {
  if (!await User.exists({ _id: req.params.userId, role: 'student', isActive: true })) fail(404, 'Student unavailable');
  const row = await Friendship.findOneAndUpdate({ _id: Friendship.pair(req.user._id, req.params.userId), recipient: req.user._id }, { $set: { status: 'accepted' } }, { new: true });
  if (!row) fail(404, 'Friend request unavailable');
  res.json({ relation: 'friends' });
}));
router.delete('/:userId', asyncHandler(async (req, res) => {
  await Friendship.deleteOne({ _id: Friendship.pair(req.user._id, req.params.userId) });
  res.json({ relation: 'none' });
}));
module.exports = router;
