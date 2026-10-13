const mongoose = require('mongoose');
const crypto = require('node:crypto');
const { Booking } = require('../models/Consultation');
const Notification = require('../models/Notification');
async function sendConsultationReminders(now = new Date()) {
  const window = { $gt: now, $lte: new Date(now.getTime() + 3600000) };
  const candidates = await Booking.find({ status: 'booked', startsAt: window, $expr: { $ne: ['$remindedFor', '$startsAt'] } }).select('_id').limit(200).lean();
  let sent = 0;
  for (const candidate of candidates) {
    const emitted = await mongoose.connection.transaction(async session => {
      const booking = await Booking.findOneAndUpdate({ _id: candidate._id, status: 'booked', startsAt: window, $expr: { $ne: ['$remindedFor', '$startsAt'] } },
        [{ $set: { remindedFor: '$startsAt' } }], { new: true, session });
      if (!booking) return false;
      for (const recipient of [booking.student, booking.advisor]) {
        const _id = new mongoose.Types.ObjectId(crypto.createHash('sha256').update(`consultation:${booking._id}:${booking.__v}:${recipient}`).digest('hex').slice(0, 24));
        await Notification.updateOne({ _id }, { $setOnInsert: { user: recipient, title: 'اقترب موعد الاستشارة',
          message: `لديك استشارة خلال الساعة القادمة: ${booking.startsAt.toISOString()}`, type: 'info',
          link: recipient.equals(booking.student) ? '/student/consultations' : '/admin/consultations' } }, { upsert: true, session });
      }
      return true;
    });
    if (emitted) sent++;
  }
  return { sent };
}
function startConsultationReminderScheduler({ enabled = process.env.CONSULTATION_REMINDERS_ENABLED === 'true', intervalMs = 60000, run = sendConsultationReminders } = {}) {
  if (!enabled) return () => {};
  if (!Number.isSafeInteger(intervalMs) || intervalMs < 60000) throw new Error('Invalid reminder interval');
  let running = false, stopped = false;
  const tick = async () => {
    if (running || stopped || mongoose.connection.readyState !== 1) return;
    running = true;
    try { await run(); } catch (error) { console.error('Consultation reminders failed', error.name); }
    finally { running = false; }
  };
  const timer = setInterval(tick, intervalMs); timer.unref(); void tick();
  return () => { stopped = true; clearInterval(timer); };
}
module.exports = { sendConsultationReminders, startConsultationReminderScheduler };
