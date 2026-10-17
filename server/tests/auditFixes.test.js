const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('audit regressions: verified Google, deletion, avatars, media retry and wallet rollback', async t => {
  process.env.JWT_SECRET = 'isolated-audit-regression';
  process.env.GOOGLE_CLIENT_ID = 'test-google';
  process.env.CLOUDINARY_CLOUD_NAME = 'audit-cloud';
  process.env.CLOUDINARY_API_KEY = 'dummy'; process.env.CLOUDINARY_API_SECRET = 'dummy';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const mailer = require('../src/utils/mailer'); const emails = [];
    mailer.isMailerConfigured = () => true; mailer.sendContactEmail = async mail => emails.push(mail);
    const { OAuth2Client } = require('google-auth-library');
    OAuth2Client.prototype.verifyIdToken = async () => ({ getPayload: () => ({ sub: 'audit-google', email: 'google@audit.test', email_verified: true }) });
    const upload = require('../src/utils/uploadToCloudinary');
    let uploadNumber = 0;
    upload.uploadFileToCloudinary = async (_file, folder) => {
      const publicId = `${folder}/audit-${++uploadNumber}`;
      return { publicId, url: `https://res.cloudinary.com/audit-cloud/image/upload/v1/${publicId}.png`, resourceType: 'image' };
    };
    const app = require('../src/app');
    const User = require('../src/models/User'); const { Story, StoryStats, StoryInteraction } = require('../src/models/Stories');
    const Job = require('../src/models/MaintenanceJob'); const Invoice = require('../src/models/Invoice');
    const Entry = require('../src/models/StudentWalletEntry');
    await Promise.all(Object.values(mongoose.models).map(model => model.init()));
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const origin = `http://127.0.0.1:${server.address().port}/api`;
    async function call(method, route, token, body, status = 200) {
      const response = await fetch(origin + route, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
      const data = await response.json(); assert.equal(response.status, status, JSON.stringify(data)); return data;
    }
    const code = () => emails.at(-1).text.match(/\d{6}/)[0];
    let google;
    await t.test('first and repeated verified Google login agree, 2FA stays required', async () => {
      google = await call('POST', '/auth/google', null, { credential: 'verified' });
      assert.equal(google.user.emailVerified, true);
      assert.ok((await call('POST', '/auth/google', null, { credential: 'verified' })).token);
      await User.updateOne({ _id: google.user._id }, { $set: { twoFactorEnabled: true } });
      for (let i = 0; i < 2; i++) assert.equal((await call('POST', '/auth/google', null, { credential: 'verified' }, 428)).requiresTwoFactor, true);
      assert.ok((await call('POST', '/auth/google', null, { credential: 'verified', emailCode: code() })).token);
    });
    await t.test('next rewards tier is the nearest threshold', async () => {
      const result = await call('GET', '/students/rewards', google.token);
      assert.deepEqual(result.nextTier, { name: 'silver', pointsNeeded: 500 });
    });
    await t.test('avatar persists on account, no admission document is created', async () => {
      const form = new FormData(); form.append('file', new Blob([Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex')], { type: 'image/png' }), 'avatar.png');
      const response = await fetch(origin + '/auth/avatar', { method: 'POST', headers: { Authorization: `Bearer ${google.token}` }, body: form });
      const data = await response.json(); assert.equal(response.status, 200, JSON.stringify(data));
      assert.match(data.user.avatar, /avatars\//);
      assert.equal((await call('GET', '/auth/me', google.token)).user.avatar, data.user.avatar);
      assert.equal(await require('../src/models/Document').countDocuments({ student: google.user._id }), 0);
    });
    await t.test('wallet transaction aborts debit when invoice write throws', async () => {
      await Entry.create({ student: google.user._id, direction: 'credit', kind: 'adjustment', amount: 20 });
      const invoice = await Invoice.create({ student: google.user._id, invoiceNumber: 'AUDIT-ROLLBACK', description: 'Test', amount: 10 });
      const original = Invoice.prototype.save;
      Invoice.prototype.save = function(...args) { if (String(this._id) === invoice.id) throw new Error('Injected invoice write failure'); return original.apply(this, args); };
      try { await call('POST', '/students/wallet/redeem', google.token, { invoiceId: invoice.id, amount: 10 }, 500); }
      finally { Invoice.prototype.save = original; }
      assert.equal(await Entry.countDocuments({ direction: 'debit', relatedInvoice: invoice._id }), 0);
      assert.equal((await Invoice.findById(invoice._id)).walletCreditApplied, 0);
    });
    await t.test('passwordless deletion requires single-use code and removes owned records', async () => {
      const apple = await User.create({ name: 'Apple', email: 'apple@audit.test', authProvider: 'apple', appleId: 'audit-apple' });
      const token = require('../src/utils/generateToken')(apple._id, apple.tokenVersion);
      const story = await Story.create({ author: apple._id, operationId: 'audit-delete', text: 'Test', expiresAt: new Date(Date.now() + 86400000) });
      await StoryStats.create({ user: apple._id, total_points: 100 });
      await StoryInteraction.create({ user: google.user._id, story: story._id, seenAt: new Date() });
      await require('../src/models/StudentProfile').create({ user: apple._id });
      await require('../src/models/Document').create({ student: apple._id, type: 'passport', fileName: 'passport.pdf', filePath: '/private/passport', storage: { publicId: 'private/audit-passport', resourceType: 'raw', deliveryType: 'authenticated' } });
      const { Message } = require('../src/models/MobileWorkspace');
      await Message.create({ sender: apple._id, recipient: google.user._id, body: 'Remove me' });
      const keep = await Message.create({ sender: google.user._id, recipient: google.user._id, body: 'Unrelated conversation' });
      const financial = await Invoice.create({ student: apple._id, invoiceNumber: 'AUDIT-RETAIN', description: 'Personal description', amount: 10 });
      await call('DELETE', '/auth/account', token, {}, 400);
      assert.ok(await User.exists({ _id: apple._id }));
      await call('POST', '/auth/account/verification', token, {});
      await call('DELETE', '/auth/account', token, { emailCode: code() });
      assert.equal(await User.exists({ _id: apple._id }), null);
      assert.equal(await Story.countDocuments({ author: apple._id }), 0);
      assert.equal(await StoryStats.countDocuments({ user: apple._id }), 0);
      assert.equal(await StoryInteraction.countDocuments({ story: story._id }), 0);
      assert.equal(await require('../src/models/Document').countDocuments({ student: apple._id }), 0);
      assert.equal(await Message.countDocuments({ sender: apple._id }), 0);
      assert.ok(await Message.exists({ _id: keep._id }));
      assert.ok(await Job.exists({ publicId: 'private/audit-passport', deliveryType: 'authenticated' }));
      assert.equal((await Invoice.findById(financial._id)).description, 'Deleted account — financial record');
      assert.ok(await User.exists({ _id: google.user._id }));
      await call('GET', '/auth/me', token, undefined, 401);
    });
    await t.test('expired media cleanup retries failures and waits for active story expiry', async () => {
      await Job.updateMany({}, { $set: { dueAt: new Date(Date.now() + 86400000) } });
      const { queueMedia, runMaintenance, mediaFromUrl } = require('../src/utils/mediaMaintenance');
      const { cloudinary } = require('../src/config/cloudinary');
      const url = 'https://res.cloudinary.com/audit-cloud/image/upload/v1/story-images/test/expired.png';
      assert.equal(mediaFromUrl('https://example.test/other.png'), null);
      const story = await Story.create({ author: google.user._id, operationId: 'audit-media', imageUrl: url, expiresAt: new Date(Date.now() + 86400000) });
      await queueMedia(mediaFromUrl(url));
      let calls = 0;
      cloudinary.uploader.destroy = async () => { calls++; throw new Error('Storage offline'); };
      await runMaintenance(); assert.equal(calls, 0);
      await Story.updateOne({ _id: story._id }, { $set: { expiresAt: new Date(0) } });
      await Job.updateMany({ url }, { $set: { dueAt: new Date(0) } });
      await runMaintenance(); assert.equal(calls, 1);
      assert.equal((await Job.findOne({ url })).attempts, 1);
      cloudinary.uploader.destroy = async () => ({ result: 'ok' });
      await Job.updateMany({ url }, { $set: { dueAt: new Date(0) } });
      await runMaintenance(); assert.equal(await Job.countDocuments({ url }), 0);
      assert.ok(await Story.exists({ _id: story._id }));
    });
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
