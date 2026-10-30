const router = require('express').Router();
const mongoose = require('mongoose');
const { rateLimit } = require('express-rate-limit');
const { protect } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const Block = require('../models/UserBlock');
const User = require('../models/User');
const SupportTicket = require('../models/SupportTicket');
router.use(protect);
router.use(rateLimit({ windowMs: 60000, limit: 30, keyGenerator: req => String(req.user._id), standardHeaders: 'draft-7', legacyHeaders: false }));
router.get('/blocks', run(async (req, res) => {
  res.set('Cache-Control', 'no-store').json(await Block.find({ user: req.user._id }).populate('blocked', 'name avatar').lean());
}));
router.put('/blocks/:id', run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id) || String(req.user._id) === req.params.id) return res.status(400).json({ message: 'Invalid user' });
  if (!await User.exists({ _id: req.params.id, isActive: true })) return res.status(404).json({ message: 'User unavailable' });
  await Block.updateOne({ user: req.user._id, blocked: req.params.id }, { $setOnInsert: { user: req.user._id, blocked: req.params.id } }, { upsert: true });
  res.json({ blocked: true });
}));
router.delete('/blocks/:id', run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid user' });
  await Block.deleteOne({ user: req.user._id, blocked: req.params.id });
  res.json({ blocked: false });
}));
// Reports enter the existing staff support queue for actual moderation.
router.post('/reports', run(async (req, res) => {
  const { content, reason } = req.body;
  if (typeof content !== 'string' || !content.trim() || content.length > 8000 ||
      typeof reason !== 'string' || !reason.trim() || reason.length > 1000) return res.status(400).json({ message: 'Invalid report' });
  const ticket = await SupportTicket.create({ user: req.user._id,
    requesterRole: req.user.role === 'partner' ? 'partner' : 'student',
    subject: 'Safety report — AI or community content', category: 'technical-issue',
    message: `Reason: ${reason.trim()}\n\nReported content:\n${content.trim()}`,
    status: 'open', escalated: true, escalationNote: 'Review for harmful or inappropriate content',
  });
  res.status(201).json({ id: ticket._id });
}));
module.exports = router;
