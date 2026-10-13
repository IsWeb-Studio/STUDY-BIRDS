const crypto = require('node:crypto');
const { EmailCode } = require('../models/MobileWorkspace');
const { isMailerConfigured, sendContactEmail } = require('./mailer');
const fail = (res, message, status = 400) => { res.status(status); throw new Error(message); };
const digest = (value) => crypto.createHmac('sha256', process.env.JWT_SECRET).update(value).digest('hex');
async function sendCode(user, purpose, res) {
  if (!isMailerConfigured()) fail(res, 'إرسال البريد غير مهيأ على السيرفر.', 503);
  const existing = await EmailCode.findOne({ user: user._id, purpose });
  if (existing && Date.now() - existing.updatedAt.getTime() < 60000) return;
  const code = crypto.randomInt(100000, 1000000).toString();
  const row = await EmailCode.findOneAndUpdate({ user: user._id, purpose }, { $set: {
    email: user.email, digest: digest(`${user._id}:${purpose}:${code}`), attempts: 0, expiresAt: new Date(Date.now() + 10 * 60 * 1000),
  } }, { new: true, upsert: true });
  const title = { reset: 'استعادة كلمة المرور', verify: 'تأكيد البريد', login: 'رمز تسجيل الدخول', security: 'تغيير إعدادات الأمان' }[purpose];
  try { await sendContactEmail({ to: user.email, subject: `Study Birds — ${title}`, text: `رمز التحقق: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.` }); }
  catch (e) { await EmailCode.deleteOne({ _id: row._id, digest: row.digest }); throw e; }
}
async function consume(user, purpose, code, res) {
  if (!user || typeof code !== 'string' || !/^\d{6}$/.test(code)) fail(res, 'رمز غير صحيح أو منتهي الصلاحية');
  const row = await EmailCode.findOneAndUpdate({ user: user._id, email: user.email, purpose, attempts: { $lt: 5 }, expiresAt: { $gt: new Date() } }, { $inc: { attempts: 1 } }, { new: true });
  const wanted = digest(`${user._id}:${purpose}:${code}`);
  if (!row || row.digest !== wanted) fail(res, 'رمز غير صحيح أو منتهي الصلاحية');
  const consumed = await EmailCode.deleteOne({ _id: row._id, digest: wanted });
  if (!consumed.deletedCount) fail(res, 'تم استخدام الرمز بالفعل');
}
module.exports = { sendCode, consume };
