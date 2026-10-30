const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const crypto = require('node:crypto');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('admin mobile announcements enforce access, target subscribed mobile devices, and safely retry', async () => {
  process.env.JWT_SECRET = 'announcement-isolated-test';
  delete process.env.ONESIGNAL_APP_ID;
  delete process.env.ONESIGNAL_REST_API_KEY;
  const originalFetch = global.fetch;
  let mongo, server, mode = 'accepted';
  const sent = [];
  global.fetch = async (url, options) => {
    if (url === 'https://api.onesignal.com/notifications') {
      const payload = JSON.parse(options.body); sent.push(payload);
      if (mode === 'timeout') throw new Error('Synthetic timeout');
      if (mode === 'rejected') return new Response(JSON.stringify({ errors: ['Synthetic error'] }), { status: 400 });
      if (mode === 'empty') return new Response(JSON.stringify({ id: '', errors: ['All included players are not subscribed'] }), { status: 200 });
      return new Response(JSON.stringify({ id: 'provider-campaign-id' }), { status: 200 });
    }
    return originalFetch(url, options);
  };
  try {
    mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1', launchTimeout: 60000 } });
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Announcement = require('../src/models/PushAnnouncement');
    await Announcement.init();
    const admin = await User.create({ name: 'Admin', email: 'admin@announcement.test', role: 'admin' });
    const employee = await User.create({ name: 'Employee', email: 'employee@announcement.test', role: 'employee', permissions: ['student-notifications'] });
    const student = await User.create({ name: 'Student', email: 'student@announcement.test' });
    const otherAdmin = await User.create({ name: 'Other admin', email: 'other@announcement.test', role: 'admin' });
    server = require('../src/app').listen(0, '127.0.0.1');
    await new Promise(resolve => server.once('listening', resolve));
    const base = `http://127.0.0.1:${server.address().port}/api/admin/push-announcements`;
    const call = async (user, body) => {
      const response = await originalFetch(base, { method: body ? 'POST' : 'GET', headers: {
        'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${jwt.sign({ userId: String(user._id) }, process.env.JWT_SECRET, { expiresIn: '1h' })}` } : {}),
      }, ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: response.status, data: await response.json() };
    };
    const draft = () => ({ title: 'تحديث التطبيق', body: 'ميزات جديدة متاحة', requestId: crypto.randomUUID() });
    const preferences = async (user, body) => {
      const response = await originalFetch(base.replace('/admin/push-announcements', '/mobile-security/notification-preferences'), {
        method: body ? 'PUT' : 'GET', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ userId: String(user._id) }, process.env.JWT_SECRET, { expiresIn: '1h' })}` },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      return { status: response.status, data: await response.json() };
    };
    assert.equal((await preferences(student)).data._initialized, false);
    assert.equal((await preferences(student, { announcements: false })).data.announcements, false);
    assert.equal((await preferences(student)).data._initialized, true);
    assert.equal((await preferences(admin)).data.announcements, true);
    assert.equal((await preferences(student, { announcements: 'false' })).status, 400);
    assert.equal((await preferences(student, { role: true })).status, 400);
    assert.equal((await preferences(student, { support: false })).data.announcements, false);
    assert.equal((await call(null)).status, 401);
    assert.equal((await call(student, draft())).status, 403);
    assert.equal((await call(employee, draft())).status, 403);
    assert.equal((await call(admin, draft())).status, 503);
    assert.equal(sent.length, 0);
    process.env.ONESIGNAL_APP_ID = 'isolated-app'; process.env.ONESIGNAL_REST_API_KEY = 'test-only';
    assert.equal((await call(admin, { ...draft(), title: ' ' })).status, 400);
    assert.equal((await call(admin, { ...draft(), requestId: 'bad' })).status, 400);
    const first = draft();
    assert.equal((await call(admin, first)).data.status, 'accepted');
    assert.equal((await call(admin, first)).data.status, 'accepted');
    assert.equal(sent.length, 1);
    assert.equal(sent[0].included_segments, undefined);
    assert.deepEqual(sent[0].filters, [
      { field: 'tag', key: 'sb_app_announcements', relation: 'not_exists' },
      { operator: 'OR' },
      { field: 'tag', key: 'sb_app_announcements', relation: '=', value: 'true' },
    ]);
    assert.equal(sent[0].isAndroid, true); assert.equal(sent[0].isIos, true);
    assert.equal(sent[0].include_aliases, undefined);
    assert.equal(sent[0].contents.ar, first.body);
    assert.match(sent[0].idempotency_key, /^[0-9a-f-]{36}$/);
    assert.equal((await call(admin, { ...first, body: 'Changed' })).status, 409);
    const retry = draft(); mode = 'timeout';
    assert.equal((await call(admin, retry)).status, 502);
    assert.equal((await Announcement.findOne({ requestId: retry.requestId })).status, 'uncertain');
    mode = 'accepted'; assert.equal((await call(admin, retry)).data.status, 'accepted');
    assert.equal(sent[1].idempotency_key, sent[2].idempotency_key);
    const existing = await Announcement.findOne({ requestId: retry.requestId });
    const sentBeforeOtherAdmin = sent.length;
    assert.equal((await call(otherAdmin, { ...retry, announcementId: String(existing._id) })).data.status, 'accepted');
    assert.equal(sent.length, sentBeforeOtherAdmin);
    assert.equal(await Announcement.countDocuments({ requestId: retry.requestId }), 1);
    assert.equal((await call(otherAdmin, { ...retry, announcementId: 'bad-id' })).status, 400);
    const empty = draft(); mode = 'empty'; assert.equal((await call(admin, empty)).data.status, 'no_subscribers');
    mode = 'rejected'; assert.equal((await call(admin, draft())).status, 502);
    mode = 'accepted'; const concurrent = draft();
    const results = await Promise.all([call(admin, concurrent), call(admin, concurrent)]);
    assert.ok(results.every(r => r.data.status === 'accepted'));
    assert.equal(await Announcement.countDocuments({ requestId: concurrent.requestId }), 1);
    const payloads = sent.filter(p => p.headings.ar === concurrent.title && p.data.announcementId === results[0].data._id);
    assert.equal(new Set(payloads.map(p => p.idempotency_key)).size, 1);
    assert.equal((await call(admin)).data.enabled, true);
    const old = draft();
    await Announcement.create({ ...old, createdBy: admin._id, createdAt: new Date(Date.now() - 2 * 86400000) });
    const before = sent.length; assert.equal((await call(admin, old)).status, 409); assert.equal(sent.length, before);
  } finally {
    global.fetch = originalFetch;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  }
});
