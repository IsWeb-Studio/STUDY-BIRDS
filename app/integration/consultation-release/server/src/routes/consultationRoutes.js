const express = require('express');
const mongoose = require('mongoose');
const { Slot, Booking } = require('../models/Consultation');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { protect, authorize } = require('../middleware/authMiddleware');
const { requireSection, hasSection } = require('../middleware/employeeAccess');
const run = require('../utils/asyncHandler');
const router = express.Router();
const HALF_HOUR = 1800000;
const advisors = { role: 'employee', isActive: true, permissions: 'consultations' };
const fail = (code, message) => { const error = new Error(message); error.httpStatus = code; throw error; };
const validId = value => typeof value === 'string' && mongoose.isValidObjectId(value);
const validVersion = value => Number.isInteger(value) && value >= 0;
function url(value) {
  if (typeof value !== 'string' || value.length > 1000) return false;
  try { const u = new URL(value); return u.protocol === 'https:' && !u.username && !u.password; } catch { return false; }
}
function validSlot({ advisorId, startsAt, mode, meetingUrl = '', instructions = '' }) {
  const start = typeof startsAt === 'string' ? new Date(startsAt) : new Date(NaN);
  return validId(advisorId) && Number.isFinite(start.getTime()) && start > new Date()
    && start.getTime() <= Date.now() + 90 * 86400000 && start.getTime() % HALF_HOUR === 0
    && ['online', 'phone', 'office'].includes(mode) && typeof instructions === 'string' && instructions.length <= 500
    && typeof meetingUrl === 'string' && (mode === 'online' ? url(meetingUrl) : !!instructions.trim());
}
function visibleBookingQuery(user) {
  if (user.role === 'student') return { student: user._id };
  if (!hasSection(user, 'consultations')) fail(403, 'Access denied');
  return user.role === 'admin' ? {} : { advisor: user._id };
}
// Every reservation, booking and notification commits together. No production URI is used by tests.
async function transaction(res, work) {
  try {
    // Await unique indexes on first boot before accepting booking writes.
    await Promise.all([Slot.init(), Booking.init()]);
    return await mongoose.connection.transaction(work);
  }
  catch (error) {
    if (error.code === 11000) { res.status(409); throw new Error('الموعد محجوز أو لديك استشارة في الوقت نفسه. حدّث المواعيد.'); }
    if (error.code === 20) { res.status(503); throw new Error('خدمة الحجز تحتاج تهيئة قاعدة البيانات. تواصل مع الفريق.'); }
    if (error.httpStatus) res.status(error.httpStatus);
    throw error;
  }
}
async function reserve(id, reservation, session) {
  const slot = await Slot.findOneAndUpdate({ _id: id, enabled: true, reservation: null, startsAt: { $gt: new Date() } },
    { $set: { reservation }, $inc: { __v: 1 } }, { new: true, session });
  if (!slot) fail(409, 'لم يعد الموعد متاحًا. اختر موعدًا آخر.');
  if (!await User.exists({ _id: slot.advisor, ...advisors }).session(session)) fail(409, 'المستشار غير متاح حاليًا.');
  return slot;
}
async function notify(booking, action, session) {
  const title = { booked: 'تم تأكيد الاستشارة', cancelled: 'أُلغيت الاستشارة', rescheduled: 'تم تغيير موعد الاستشارة' }[action];
  await Notification.create([booking.student, booking.advisor].map(user => ({ user, title,
    message: `${title}: ${booking.startsAt.toISOString()}`, type: 'info', link: user.equals(booking.student) ? '/student/consultations' : '/admin/consultations' })), { session, ordered: true });
}
router.use(protect);
router.get('/slots', authorize('student'), run(async (req, res) => {
  const active = await User.find(advisors).select('_id').lean();
  const query = { enabled: true, reservation: null, advisor: { $in: active.map(a => a._id) }, startsAt: { $gt: new Date(), $lte: new Date(Date.now() + 90 * 86400000) } };
  if (req.query.mode && !['online', 'phone', 'office'].includes(req.query.mode)) return res.status(400).json({ message: 'Invalid consultation mode' });
  if (req.query.mode) query.mode = req.query.mode;
  res.json(await Slot.find(query).select('_id advisor startsAt mode __v').populate('advisor', 'name').sort({ startsAt: 1, _id: 1 }).limit(500).lean());
}));
router.get('/mine', authorize('student'), run(async (req, res) => {
  const rows = await Booking.find({ student: req.user._id }).populate('advisor', 'name').populate('slot', 'mode meetingUrl instructions').sort({ startsAt: -1 }).limit(200).lean();
  res.json(rows.map(row => row.status === 'cancelled' && row.slot ? { ...row, slot: { ...row.slot, meetingUrl: '' } } : row));
}));
router.post('/bookings', authorize('student'), run(async (req, res) => {
  if (!validId(req.body.slotId)) return res.status(400).json({ message: 'Invalid slot' });
  const result = await transaction(res, async session => {
    const id = new mongoose.Types.ObjectId(); const slot = await reserve(req.body.slotId, id, session);
    const [booking] = await Booking.create([{ _id: id, student: req.user._id, advisor: slot.advisor, slot: slot._id, startsAt: slot.startsAt,
      history: [{ action: 'booked', slot: slot._id, startsAt: slot.startsAt, changedBy: req.user._id, changedAt: new Date() }] }], { session });
    await notify(booking, 'booked', session); return booking;
  });
  res.status(201).json(result);
}));
router.post('/bookings/:id/cancel', (req, res, next) => req.user.role === 'student' || hasSection(req.user, 'consultations') ? next() : res.status(403).json({ message: 'Access denied' }), run(async (req, res) => {
  if (!validId(req.params.id) || !validVersion(req.body.version)) return res.status(400).json({ message: 'Invalid booking/version' });
  const scope = visibleBookingQuery(req.user);
  const result = await transaction(res, async session => {
    const booking = await Booking.findOne({ _id: req.params.id, ...scope }).session(session);
    if (!booking) fail(404, 'Booking not found');
    if (booking.status !== 'booked' || booking.__v !== req.body.version || booking.startsAt <= new Date()) fail(409, 'حدّث بيانات الموعد؛ لا يمكن إلغاء هذا الحجز الآن.');
    const cancelled = await Booking.findOneAndUpdate({ _id: booking._id, __v: booking.__v, status: 'booked' }, { $set: { status: 'cancelled' }, $inc: { __v: 1 },
      $push: { history: { action: 'cancelled', slot: booking.slot, startsAt: booking.startsAt, changedBy: req.user._id, changedAt: new Date() } } }, { new: true, session });
    if (!cancelled) fail(409, 'Booking changed');
    await Slot.updateOne({ _id: booking.slot, reservation: booking._id }, { $set: { reservation: null }, $inc: { __v: 1 } }, { session });
    await notify(cancelled, 'cancelled', session); return cancelled;
  });
  res.json(result);
}));
router.post('/bookings/:id/reschedule', authorize('student'), run(async (req, res) => {
  if (!validId(req.params.id) || !validId(req.body.slotId) || !validVersion(req.body.version)) return res.status(400).json({ message: 'Invalid booking/slot/version' });
  const result = await transaction(res, async session => {
    const booking = await Booking.findOne({ _id: req.params.id, student: req.user._id }).session(session);
    if (!booking) fail(404, 'Booking not found');
    if (booking.__v !== req.body.version || booking.status !== 'booked' || booking.startsAt <= new Date()) fail(409, 'حدّث بيانات الحجز قبل تغيير الموعد.');
    if (String(booking.slot) === req.body.slotId) fail(400, 'Choose a different slot');
    const slot = await reserve(req.body.slotId, booking._id, session);
    const updated = await Booking.findOneAndUpdate({ _id: booking._id, __v: booking.__v, status: 'booked' }, {
      $set: { slot: slot._id, advisor: slot.advisor, startsAt: slot.startsAt, remindedFor: null }, $inc: { __v: 1 },
      $push: { history: { action: 'rescheduled', slot: slot._id, startsAt: slot.startsAt, changedBy: req.user._id, changedAt: new Date() } },
    }, { new: true, session });
    if (!updated) fail(409, 'Booking changed');
    await Slot.updateOne({ _id: booking.slot, reservation: booking._id }, { $set: { reservation: null }, $inc: { __v: 1 } }, { session });
    if (!booking.advisor.equals(updated.advisor)) {
      await Notification.create([{ user: booking.advisor, title: 'تغيّر حجز الاستشارة',
        message: `أصبح موعدك ${booking.startsAt.toISOString()} متاحًا بعد انتقال الطالب إلى موعد آخر.`, type: 'info', link: '/admin/consultations' }], { session });
    }
    await notify(updated, 'rescheduled', session); return updated;
  });
  res.json(result);
}));
router.use('/staff', requireSection('consultations'));
router.put('/staff/bookings/:id/outcome', run(async (req, res) => {
  const { version, result, summary, nextSteps = '' } = req.body;
  if (!validId(req.params.id) || !validVersion(version) || !['completed', 'no-show'].includes(result)
    || typeof summary !== 'string' || !summary.trim() || summary.length > 2000
    || typeof nextSteps !== 'string' || nextSteps.length > 2000) {
    return res.status(400).json({ message: 'اختر نتيجة الاستشارة وأدخل ملخصًا حتى 2000 حرف وخطوات تالية حتى 2000 حرف.' });
  }
  const updated = await transaction(res, async session => {
    const booking = await Booking.findOne({ _id: req.params.id, ...visibleBookingQuery(req.user) }).session(session);
    if (!booking) fail(404, 'Booking not found');
    if (booking.status === 'cancelled' || booking.__v !== version || booking.startsAt.getTime() + HALF_HOUR > Date.now()) {
      fail(409, 'يمكن تسجيل النتيجة بعد انتهاء الاستشارة فقط. حدّث الحجز قبل المحاولة مجددًا.');
    }
    const outcome = { result, summary: summary.trim(), nextSteps: nextSteps.trim(), recordedBy: req.user._id, recordedAt: new Date() };
    const saved = await Booking.findOneAndUpdate({ _id: booking._id, __v: version, status: booking.status }, {
      $set: { status: result, outcome }, $inc: { __v: 1 }, $push: { outcomeHistory: outcome },
    }, { new: true, session, runValidators: true });
    if (!saved) fail(409, 'Booking changed');
    await Notification.create([{ user: booking.student, title: 'تم تحديث نتيجة الاستشارة',
      message: 'يمكنك مراجعة ملخص الاستشارة والخطوات التالية من صفحة مواعيدك.',
      type: 'info', link: '/student/consultations' }], { session });
    return saved;
  });
  res.json(updated);
}));
router.get('/staff/advisors', run(async (req, res) => res.json(await User.find({ ...advisors, ...(req.user.role === 'admin' ? {} : { _id: req.user._id }) }).select('name').sort({ name: 1 }).lean())));
router.get('/staff/slots', run(async (req, res) => res.json(await Slot.find({ ...(req.user.role === 'admin' ? {} : { advisor: req.user._id }), startsAt: { $gt: new Date(Date.now() - 86400000) } }).populate('advisor', 'name').sort({ startsAt: 1 }).limit(500).lean())));
router.get('/staff/bookings', run(async (req, res) => res.json(await Booking.find(visibleBookingQuery(req.user)).populate('student', 'name').populate('advisor', 'name').populate('slot', 'mode meetingUrl instructions').sort({ startsAt: -1 }).limit(200).lean())));
router.post('/staff/slots', run(async (req, res) => {
  const { advisorId, startsAt, mode, meetingUrl = '', instructions = '' } = req.body;
  const start = typeof startsAt === 'string' ? new Date(startsAt) : new Date(NaN);
  if (!validSlot(req.body)) {
    return res.status(400).json({ message: 'اختر موعدًا مستقبليًا على رأس الساعة أو نصفها خلال 90 يومًا، وأدخل رابط اجتماع HTTPS أو تعليمات الاتصال/المكتب.' });
  }
  if (req.user.role !== 'admin' && advisorId !== String(req.user._id)) return res.status(403).json({ message: 'Only your own availability can be published' });
  if (!await User.exists({ _id: advisorId, ...advisors })) return res.status(400).json({ message: 'Choose an active authorized consultant' });
  try { res.status(201).json(await Slot.create({ advisor: advisorId, startsAt: start, mode, meetingUrl: mode === 'online' ? meetingUrl : '', instructions: instructions.trim() })); }
  catch (error) { if (error.code === 11000) return res.status(409).json({ message: 'يوجد موعد لهذا المستشار في الوقت نفسه.' }); throw error; }
}));
router.post('/staff/slots/batch', run(async (req, res) => {
  const { advisorId, startsAt, mode, meetingUrl = '', instructions = '' } = req.body;
  if (!Array.isArray(startsAt) || startsAt.length < 1 || startsAt.length > 12
    || startsAt.some(date => !validSlot({ advisorId, startsAt: date, mode, meetingUrl, instructions }))
    || new Set(startsAt.map(date => new Date(date).getTime())).size !== startsAt.length) {
    return res.status(400).json({ message: 'اختر حتى 12 موعدًا مختلفًا خلال 90 يومًا على شبكة نصف الساعة، مع رابط HTTPS أو تعليمات الاتصال.' });
  }
  if (req.user.role !== 'admin' && advisorId !== String(req.user._id)) return res.status(403).json({ message: 'Only your own availability can be published' });
  const result = await transaction(res, async session => {
    if (!await User.exists({ _id: advisorId, ...advisors }).session(session)) fail(400, 'Choose an active authorized consultant');
    return Slot.create(startsAt.map(date => ({ advisor: advisorId, startsAt: new Date(date), mode,
      meetingUrl: mode === 'online' ? meetingUrl : '', instructions: instructions.trim() })), { session, ordered: true });
  });
  res.status(201).json(result);
}));
router.patch('/staff/slots/:id', run(async (req, res) => {
  if (!validId(req.params.id) || !validVersion(req.body.version) || typeof req.body.enabled !== 'boolean') return res.status(400).json({ message: 'Invalid slot/version' });
  const slot = await Slot.findOneAndUpdate({ _id: req.params.id, ...(req.user.role === 'admin' ? {} : { advisor: req.user._id }), reservation: null, startsAt: { $gt: new Date() }, __v: req.body.version },
    { $set: { enabled: req.body.enabled }, $inc: { __v: 1 } }, { new: true });
  if (!slot) return res.status(409).json({ message: 'الموعد تغيّر أو محجوز أو غير متاح لك. ألغِ الحجز أولًا عند الحاجة.' });
  res.json(slot);
}));
module.exports = router;
