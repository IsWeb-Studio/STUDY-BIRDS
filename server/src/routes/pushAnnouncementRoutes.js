const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { protect, authorize } = require('../middleware/authMiddleware');
const asyncHandler = require('../utils/asyncHandler');
const Announcement = require('../models/PushAnnouncement');
const mongoose = require('mongoose');
const { isPushEnabled, sendPushAnnouncement } = require('../utils/pushNotifications');
const router = express.Router();
router.use(protect, authorize('admin'));
router.get('/', asyncHandler(async (req, res) => {
  const items = await Announcement.find().sort({ createdAt: -1 }).limit(50).lean();
  res.json({ enabled: isPushEnabled(), items });
}));
router.post('/', rateLimit({ windowMs: 3600000, limit: 20, standardHeaders: 'draft-8', legacyHeaders: false }), asyncHandler(async (req, res) => {
  const { title, body, requestId } = req.body;
  if (typeof title !== 'string' || !title.trim() || title.trim().length > 80 ||
      typeof body !== 'string' || !body.trim() || body.trim().length > 1000 ||
      typeof requestId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId)) {
    return res.status(400).json({ message: 'Enter a title (1–80), message (1–1000), and valid request ID.' });
  }
  if (!isPushEnabled()) return res.status(503).json({ message: 'Push delivery is not configured on the server.' });
  const filter = { createdBy: req.user._id, requestId };
  let item;
  if (req.body.announcementId !== undefined) {
    if (!mongoose.isObjectIdOrHexString(req.body.announcementId)) return res.status(400).json({ message: 'Invalid announcement ID.' });
    item = await Announcement.findById(req.body.announcementId);
    if (!item) return res.status(404).json({ message: 'Announcement not found.' });
  } else try {
    item = await Announcement.findOneAndUpdate(filter, { $setOnInsert: { ...filter, title: title.trim(), body: body.trim() } }, { upsert: true, new: true, setDefaultsOnInsert: true });
  } catch (error) {
    if (error.code !== 11000) throw error;
    item = await Announcement.findOne(filter);
  }
  if (item.requestId !== requestId || item.title !== title.trim() || item.body !== body.trim()) return res.status(409).json({ message: 'This request ID already belongs to a different announcement.' });
  if (['accepted', 'no_subscribers'].includes(item.status)) return res.json(item);
  // Provider deduplication expires after 30 days. Never retry an old campaign.
  if (Date.now() - item.createdAt.getTime() > 86400000) return res.status(409).json({ message: 'This announcement is too old to retry. Check its delivery in OneSignal.' });
  try {
    const result = await sendPushAnnouncement(item);
    item = await Announcement.findByIdAndUpdate(item._id, { $set: result }, { new: true });
    res.json(item);
  } catch (error) {
    // A timeout can occur after the provider accepts a request. Keep the same
    // durable provider key for every retry, including concurrent HTTP requests.
    console.warn(`[Push announcement ${item._id}] Provider acceptance was not confirmed.`);
    await Announcement.updateOne({ _id: item._id, status: { $nin: ['accepted', 'no_subscribers'] } }, { $set: { status: 'uncertain' } });
    res.status(502).json({ message: 'Delivery could not be confirmed. Retry the same announcement safely.', requestId });
  }
}));
module.exports = router;
