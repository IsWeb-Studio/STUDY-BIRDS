const EmailDelivery = require('../models/EmailDelivery');
const { isMailerConfigured, sendContactEmail } = require('./mailer');
const { applicationStatusInfo } = require('../constants/statusCatalog');
const { websiteOrigin } = require('./brandedEmail');

function displayName(value) {
  if (value && typeof value === 'object') return value.ar || value.en || value.name || '';
  return String(value ?? '');
}

function applicationEmail(application, kind = 'submitted') {
  const student = application.student;
  const program = application.program;
  const university = program?.university;
  if (!student?.email || !program) return null;
  const info = applicationStatusInfo(application);
  const title = kind === 'submitted' ? 'تم استلام طلب رحلتك الدراسية' : `تحديث رحلتك: ${info.ar.label}`;
  const message = kind === 'submitted'
    ? 'شكرًا لاختيارك Study Birds. استلمنا طلبك بنجاح، وسيقوم فريقنا بمراجعته ومتابعة الخطوات القادمة معك.'
    : `${info.ar.meaning} ${info.ar.nextStep}`;
  const details = [
    ['اسم الطالب', student.name || application.applicantProfile?.name || 'الطالب'],
    ['رقم الطلب', String(application._id)],
    ['الجامعة', displayName(university?.name) || 'غير محدد'],
    ['البرنامج', displayName(program.title) || 'غير محدد'],
    ...(university?.country ? [['الدولة', displayName(university.country.name || university.country)]] : []),
    ['حالة الطلب', info.ar.label],
  ];
  const text = `مرحبًا ${student.name || 'بك'}،\n\n${message}\n\n${details.map(([key, value]) => `${key}: ${value}`).join('\n')}\n\nمتابعة الطلب: ${websiteOrigin()}/student/applications\nمع أطيب التحيات، فريق Study Birds`;
  return {
    key: `application:${application._id}:${kind}:${kind === 'submitted' ? 0 : application.statusTimeline?.length || 0}`,
    to: student.email, subject: `Study Birds — ${title}`, text,
    emailContent: { title, bodyText: `مرحبًا ${student.name || 'بك'}،\n\n${message}`,
      details, actionPath: '/student/applications', actionLabel: 'متابعة طلبي', preview: message },
  };
}

let draining = false;
async function deliverPendingEmails() {
  if (draining || !isMailerConfigured()) return;
  draining = true;
  try {
    for (let i = 0; i < 10; i++) {
      const now = new Date();
      const row = await EmailDelivery.findOneAndUpdate({
        $or: [
          { status: 'pending', nextAttemptAt: { $lte: now } },
          { status: 'sending', lockedUntil: { $lte: now } },
        ],
      }, { $set: { status: 'sending', lockedUntil: new Date(Date.now() + 120000) },
        $inc: { attempts: 1 } }, { new: true, sort: { createdAt: 1 } });
      if (!row) break;
      try {
        await sendContactEmail({ to: row.to, subject: row.subject, text: row.text,
          emailContent: row.emailContent });
        await EmailDelivery.updateOne({ _id: row._id, attempts: row.attempts },
          { $set: { status: 'sent', sentAt: new Date() }, $unset: { lockedUntil: 1 } });
      } catch (error) {
        await EmailDelivery.updateOne({ _id: row._id, attempts: row.attempts }, {
          $set: { status: 'pending', nextAttemptAt: new Date(Date.now() +
            Math.min(60, 2 ** Math.min(row.attempts, 6)) * 60000) },
          $unset: { lockedUntil: 1 },
        });
        console.error('Application email delivery delayed:', row._id.toString());
      }
    }
  } finally { draining = false; }
}

async function enqueueApplicationEmail(application, kind) {
  const email = applicationEmail(application, kind);
  if (!email) return;
  try {
    await EmailDelivery.updateOne({ key: email.key }, { $setOnInsert: email }, { upsert: true });
  } catch (error) {
    if (error.code !== 11000) throw error;
  }
  deliverPendingEmails().catch(() => console.error('Application email queue temporarily unavailable'));
}

function startEmailDeliveryScheduler() {
  const run = () => deliverPendingEmails().catch(() =>
    console.error('Application email queue temporarily unavailable'));
  run();
  const timer = setInterval(run, 30000);
  timer.unref();
  return () => clearInterval(timer);
}

module.exports = { applicationEmail, enqueueApplicationEmail, deliverPendingEmails, startEmailDeliveryScheduler };
