const express = require('express');
const crypto = require('node:crypto');
const User = require('../models/User');
const { Session } = require('../models/MobileWorkspace');
const { protect } = require('../middleware/authMiddleware');
const { isMailerConfigured } = require('../utils/mailer');
const run = require('../utils/asyncHandler');
const router = express.Router();
const fail = (res, message, status = 400) => { res.status(status); throw new Error(message); };
const buckets = new Map();
function throttle(req, res, next) {
  const now = Date.now(); const key = req.ip;
  for (const [ip, value] of buckets) if (now > value.until) buckets.delete(ip);
  const bucket = buckets.get(key) || { count: 0, until: now + 15 * 60 * 1000 };
  if (++bucket.count > 30) return res.status(429).json({ message: 'محاولات كثيرة. حاول بعد 15 دقيقة.' });
  buckets.set(key, bucket); next();
}
router.use(throttle);
const { sendCode, consume } = require('../utils/mobileEmailCodes');
router.post('/reset/request', run(async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  if (!isMailerConfigured()) fail(res, 'إرسال البريد غير مهيأ على السيرفر.', 503);
  const user = await User.findOne({ email, isActive: true });
  if (user) await sendCode(user, 'reset', res);
  res.json({ message: 'إذا كان البريد مسجلاً، ستصلك رسالة تحتوي على رمز الاستعادة.' });
}));
router.post('/reset/confirm', run(async (req, res) => {
  if (typeof req.body.password !== 'string' || req.body.password.length < 8 || req.body.password.length > 200) fail(res, 'كلمة المرور يجب ألا تقل عن 8 أحرف');
  const user = await User.findOne({ email: String(req.body.email || '').trim().toLowerCase(), isActive: true });
  await consume(user, 'reset', req.body.code, res);
  user.password = req.body.password; user.passwordChangedAt = new Date(); user.tokenVersion = (user.tokenVersion || 0) + 1; await user.save();
  await Session.updateMany({ user: user._id }, { $set: { revoked: true } });
  res.json({ message: 'تم تغيير كلمة المرور. سجّل الدخول مجدداً.' });
}));
router.use(protect);
router.get('/two-factor', run(async (req, res) => res.json({ enabled: req.user.twoFactorEnabled === true })));
router.post('/two-factor/request', run(async (req, res) => {
  const user = await User.findById(req.user._id);
  if (!user.password) fail(res, 'عيّن كلمة مرور للحساب أولاً');
  await sendCode(user, 'security', res); res.json({ message: 'تم إرسال رمز تأكيد تغيير إعدادات الأمان.' });
}));
router.post('/two-factor/confirm', run(async (req, res) => {
  if (typeof req.body.enabled !== 'boolean') fail(res, 'Invalid security setting');
  await consume(req.user, 'security', req.body.code, res);
  await User.updateOne({ _id: req.user._id }, { $set: { twoFactorEnabled: req.body.enabled, emailVerified: true } });
  res.json({ enabled: req.body.enabled });
}));
router.post('/email/request', run(async (req, res) => {
  await sendCode(req.user, 'verify', res); res.json({ message: 'تم إرسال رمز التحقق إلى بريدك.' });
}));
router.post('/email/confirm', run(async (req, res) => {
  await consume(req.user, 'verify', req.body.code, res);
  await User.updateOne({ _id: req.user._id }, { $set: { emailVerified: true } }); res.json({ emailVerified: true });
}));
router.get('/sessions', run(async (req, res) => {
  const current = crypto.createHash('sha256').update(req.headers.authorization.slice(7)).digest('hex');
  const rows = await Session.find({ user: req.user._id, revoked: false, expiresAt: { $gt: new Date() } }).sort({ lastSeen: -1 }).lean();
  res.json(rows.map(row => ({ _id: row._id, device: row.device, lastSeen: row.lastSeen, current: row.digest === current })));
}));
router.delete('/sessions/:id', run(async (req, res) => {
  const mongoose = require('mongoose');
  if (!mongoose.isValidObjectId(req.params.id)) fail(res, 'Invalid session');
  const row = await Session.findOneAndUpdate({ _id: req.params.id, user: req.user._id }, { $set: { revoked: true } });
  if (!row) fail(res, 'الجلسة غير موجودة', 404); res.json({ revoked: true });
}));
module.exports = router;
