const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { renderBrandedEmail } = require('../src/utils/brandedEmail');

function loadEmails(model = {}, mailer = {}) {
  const sandbox = { module: { exports: {} }, console, setInterval, clearInterval,
    require: (name) => name === '../models/EmailDelivery' ? model :
      name === './mailer' ? { isMailerConfigured: () => false, ...mailer } :
      require(path.join(__dirname, '../src/utils', name)) };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/utils/applicationEmails.js'), 'utf8'), sandbox);
  return sandbox.module.exports;
}

const application = { _id: 'app-123', status: 'submitted', detailedStatus: 'submitted',
  statusTimeline: [{ status: 'submitted' }], student: { name: 'Student', email: 'student@example.test' },
  program: { title: 'Medicine', university: { name: 'University', country: { name: 'Turkey' } } } };

test('all messages include responsive branding and escaped content', () => {
  const html = renderBrandedEmail({ subject: '<img onerror=attack>', text: '<script>bad</script>' });
  assert.match(html, /email-assets\/header.png/);
  assert.match(html, /email-assets\/logo.png/);
  assert.match(html, /max-width:600px/);
  assert.match(html, /dir="rtl"/);
  assert.match(html, /&lt;script&gt;/);
  assert.doesNotMatch(html, /<script>/);
});

test('verification codes use the same branded shell and stay left to right', () => {
  const html = renderBrandedEmail({ subject: 'Verify', text: 'Code: 123456',
    emailContent: { code: '123456', bodyText: 'Enter your code.' } });
  assert.match(html, /dir="ltr"/);
  assert.equal((html.match(/123456/g) || []).length, 1);
});

test('application confirmation addresses the authenticated student and lists real details', () => {
  const email = loadEmails().applicationEmail({ ...application,
    applicantProfile: { email: 'other@example.test' } });
  assert.equal(email.to, 'student@example.test');
  for (const value of ['Student', 'app-123', 'Medicine', 'University', 'Turkey']) {
    assert.ok(email.text.includes(value));
  }
  const html = renderBrandedEmail(email);
  assert.match(html, /https:\/\/studybirds.net\/student\/applications/);
  assert.doesNotMatch(html, /StudyFans|Acceptance Letter/);
  assert.equal(email.key, 'application:app-123:submitted:0');
});

test('unsafe buttons and HTML in application fields cannot inject email content', () => {
  const html = renderBrandedEmail({ subject: 'Update', text: 'Hello', emailContent: {
    actionPath: '//evil.example.test', details: [['Student', '<script>bad</script>']] } });
  assert.doesNotMatch(html, /href=".*evil/);
  assert.match(html, /&lt;script&gt;/);
});

test('submission is queued durably even if email is not configured', async () => {
  const updates = [];
  const emails = loadEmails({ updateOne: async (...args) => updates.push(args) });
  await emails.enqueueApplicationEmail(application, 'submitted');
  assert.equal(updates.length, 1);
  assert.equal(updates[0][0].key, 'application:app-123:submitted:0');
  assert.equal(updates[0][2].upsert, true);
});

test('provider failure leaves the saved message pending for retry', async () => {
  let claimed = false;
  const updates = [];
  const email = loadEmails().applicationEmail(application);
  const emails = loadEmails({ findOneAndUpdate: async () => {
    if (claimed) return null;
    claimed = true;
    return { ...email, _id: 'delivery', attempts: 1 };
  }, updateOne: async (...args) => updates.push(args) }, {
    isMailerConfigured: () => true,
    sendContactEmail: async () => { throw new Error('Provider down'); },
  });
  await emails.deliverPendingEmails();
  assert.equal(updates[0][1].$set.status, 'pending');
  assert.ok(updates[0][1].$set.nextAttemptAt.getTime() > Date.now());
});

test('delivered messages are marked sent and status events have separate keys', async () => {
  let claimed = false;
  const updates = [];
  const email = loadEmails().applicationEmail(application);
  const emails = loadEmails({ findOneAndUpdate: async () => {
    if (claimed) return null;
    claimed = true;
    return { ...email, _id: 'delivery', attempts: 1 };
  }, updateOne: async (...args) => updates.push(args) }, {
    isMailerConfigured: () => true, sendContactEmail: async () => {},
  });
  await emails.deliverPendingEmails();
  assert.equal(updates[0][1].$set.status, 'sent');
  const statusEmail = emails.applicationEmail({ ...application, statusTimeline: [{}, {}] }, 'status');
  assert.notEqual(statusEmail.key, email.key);
});

test('mailer brands existing text emails while preserving plaintext verification codes', async () => {
  let message;
  const sandbox = { module: { exports: {} }, process: { env: {
    SMTP_HOST: 'smtp.example.test', SMTP_USER: 'sender@example.test',
    SMTP_PASS: 'test-only', SMTP_FROM: 'sender@example.test',
  } }, require: (name) => name === 'nodemailer'
    ? { createTransport: () => ({ sendMail: async (mail) => { message = mail; } }) }
    : name === './brandedEmail' ? { renderBrandedEmail } : {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/utils/mailer.js'), 'utf8'), sandbox);
  await sandbox.module.exports.sendContactEmail({ to: 'student@example.test',
    subject: 'Verify', text: 'Your code: 123456' });
  assert.equal(message.text, 'Your code: 123456');
  assert.match(message.html, /email-assets\/header.png/);
  assert.equal(message.from.name, 'Study Birds');
});

test('creating a valid journey queues its confirmation before returning success', async () => {
  const queued = [];
  const populated = { ...application };
  const query = { populate() { return this; }, then(resolve, reject) {
    return Promise.resolve(populated).then(resolve, reject);
  } };
  const imports = {
    '../utils/applicationRequirements': { requiredDocumentTypesFor: () => [], missingDocumentTypes: () => [] },
    '../utils/journeyAutomation': {}, mongoose: { isValidObjectId: () => true },
    '../models/Application': { findOne: async () => null, create: async () => populated,
      countDocuments: async () => 2, findById: () => query },
    '../models/Program': { findById: () => ({ populate: async () =>
      ({ _id: 'program', title: 'Medicine', university: { _id: 'university' } }) }) },
    '../models/Document': { find: async () => [] },
    '../models/Notification': { create: async () => {} },
    '../utils/asyncHandler': (fn) => fn,
    '../constants/roles': {}, '../constants/statusCatalog': {},
    '../utils/hydrateApplications': { hydrateApplicationsWithStudentProfiles: async (value) => value },
    '../utils/studentWallet': {},
    '../utils/applicationEmails': { enqueueApplicationEmail: async (...args) => queued.push(args) },
  };
  const sandbox = { module: { exports: {} }, require: (name) => {
    if (!Object.hasOwn(imports, name)) throw new Error(`Unexpected import ${name}`);
    return imports[name];
  } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/controllers/applicationController.js'), 'utf8'), sandbox);
  let status;
  const res = { status(value) { status = value; return this; }, json(value) {
    assert.equal(queued.length, 1);
    assert.equal(value._id, populated._id);
  } };
  await sandbox.module.exports.createApplication({ body: { programId: 'program' },
    user: { _id: 'student' } }, res);
  assert.equal(status, 201);
  assert.equal(queued[0][1], 'submitted');
  assert.equal(queued[0][0].student.email, 'student@example.test');
});
