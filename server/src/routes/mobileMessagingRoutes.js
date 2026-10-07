const express = require('express');
const mongoose = require('mongoose');
const { protect } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const User = require('../models/User');
const ParentLink = require('../models/ParentLink');
const Application = require('../models/Application');
const Notification = require('../models/Notification');
const { Message } = require('../models/MobileWorkspace');
const sse = require('../utils/sseClients');
const router = express.Router();
router.use(protect);

async function contactFilter(user) {
  if (user.role === 'admin') return { isActive: true, _id: { $ne: user._id } };
  const ids = [];
  if (user.role === 'parent') {
    const links = await ParentLink.find({ parent: user._id, status: 'approved' }).select('student').lean();
    ids.push(...links.map(link => link.student));
  }
  if (user.role === 'student') {
    const links = await ParentLink.find({ student: user._id, status: 'approved' }).select('parent').lean();
    ids.push(...links.map(link => link.parent));
    const universities = await Application.distinct('university', { student: user._id });
    const accounts = await User.find({ role: 'university', linkedUniversity: { $in: universities }, isActive: true }).select('_id').lean();
    ids.push(...accounts.map(account => account._id));
  }
  if (user.role === 'university' && user.linkedUniversity) {
    ids.push(...await Application.distinct('student', { university: user.linkedUniversity }));
  }
  return { isActive: true, _id: { $ne: user._id }, $or: [{ role: 'admin' }, { _id: { $in: ids } }] };
}
async function requireContact(user, recipient, res) {
  if (!mongoose.isValidObjectId(recipient)) { res.status(400); throw new Error('Invalid recipient'); }
  const filter = await contactFilter(user);
  const contact = await User.findOne({ $and: [filter, { _id: recipient }] }).select('_id name role');
  if (!contact) { res.status(403); throw new Error('This contact is unavailable'); }
  return contact;
}
router.get('/contacts', run(async (req, res) => {
  res.json(await User.find(await contactFilter(req.user)).select('name role').sort({ name: 1 }).limit(200).lean());
}));
router.get('/messages', run(async (req, res) => {
  const recipient = req.query.recipient;
  await requireContact(req.user, recipient, res);
  const filter = { $or: [{ sender: req.user._id, recipient }, { sender: recipient, recipient: req.user._id }] };
  if (req.query.before) {
    if (!mongoose.isValidObjectId(req.query.before)) { res.status(400); throw new Error('Invalid cursor'); }
    filter._id = { $lt: req.query.before };
  }
  const rows = await Message.find(filter).sort({ _id: -1 }).limit(50).select('sender recipient body readAt createdAt').lean();
  res.set('Cache-Control', 'no-store').json(rows.reverse());
}));
router.post('/messages', run(async (req, res) => {
  const contact = await requireContact(req.user, req.body.recipient, res);
  if (typeof req.body.body !== 'string' || !req.body.body.trim() || req.body.body.length > 4000) {
    res.status(400); throw new Error('Message must contain 1 to 4000 characters');
  }
  const recent = await Message.countDocuments({ sender: req.user._id, createdAt: { $gt: new Date(Date.now() - 60000) } });
  if (recent >= 30) { res.status(429); throw new Error('Too many messages. Please wait.'); }
  const message = await Message.create({ sender: req.user._id, recipient: contact._id, body: req.body.body.trim() });
  // Push real-time event to recipient via SSE (non-blocking)
  const messageData = { _id: message._id, sender: req.user._id, recipient: contact._id, body: message.body, createdAt: message.createdAt };
  sse.push(contact._id, 'message', messageData);
  // Notification failure must never report a successfully saved message as unsent.
  try {
    await Notification.create({ user: contact._id, title: 'رسالة جديدة', message: `لديك رسالة من ${req.user.name}`, type: 'info' });
  } catch (error) { console.error('Message notification creation failed:', error.name); }
  res.status(201).json(message);
}));
router.post('/messages/read', run(async (req, res) => {
  await requireContact(req.user, req.body.sender, res);
  await Message.updateMany({ sender: req.body.sender, recipient: req.user._id, readAt: null }, { $set: { readAt: new Date() } });
  res.json({ read: true });
}));
// GET /api/messaging/events — SSE stream for real-time message delivery
router.get('/events', (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-store',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.flushHeaders();
  res.write(': connected\n\n');

  sse.register(req.user._id, res);

  // Heartbeat every 25 seconds to keep proxies from closing idle connections
  const heartbeat = setInterval(() => {
    try { res.write(': ping\n\n'); } catch { clearInterval(heartbeat); }
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    sse.unregister(req.user._id, res);
  });
});

module.exports = router;
