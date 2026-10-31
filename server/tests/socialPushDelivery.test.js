const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('story loves and messages reach the correct push account once, respecting preferences and mute', async () => {
  Object.assign(process.env, { JWT_SECRET: 'social-push', ONESIGNAL_APP_ID: 'test-app', ONESIGNAL_REST_API_KEY: 'test-key' });
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
  const nativeFetch = global.fetch;
  const pushes = [];
  global.fetch = async (url, options) => {
    if (String(url) === 'https://api.onesignal.com/notifications') {
      pushes.push(JSON.parse(options.body)); return { ok: true, json: async () => ({ id: 'accepted', recipients: 1 }) };
    }
    return nativeFetch(url, options);
  };
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Notification = require('../src/models/Notification');
    const { Story } = require('../src/models/Stories');
    const owner = await User.create({ name: 'Owner', email: 'owner@test.example', role: 'student' });
    const friend = await User.create({ name: 'Friend', email: 'friend@test.example', role: 'student' });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, user, body) {
      const res = await fetch(`http://127.0.0.1:${server.address().port}/api${route}`, { method,
        headers: { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined });
      const data = await res.json(); assert.equal(res.ok, true, JSON.stringify(data)); return data;
    }
    const wait = async count => { for (let i = 0; i < 100 && pushes.length < count; i++) await new Promise(r => setTimeout(r, 10)); assert.equal(pushes.length, count); };
    const story = await Story.create({ author: owner._id, operationId: 'push-story', text: 'Story', expiresAt: new Date(Date.now() + 60000) });
    await call('POST', `/stories/${story._id}/love`, friend);
    await call('POST', `/stories/${story._id}/love`, friend);
    await wait(1);
    assert.equal(await Notification.countDocuments({ user: owner._id }), 1);
    assert.deepEqual(pushes[0].include_aliases, { external_id: [String(owner._id)] });
    assert.equal(pushes[0].data.link, `/student/stories/${story._id}/viewers`);
    assert.ok(pushes[0].idempotency_key); assert.equal(pushes[0].data.category, 'community');
    assert.equal((await call('GET', `/stories/${story._id}/viewers`, owner)).viewers[0].loved, true);
    await call('POST', `/stories/${story._id}/love`, owner);
    assert.equal(await Notification.countDocuments({ user: owner._id }), 1, 'self-like must not notify');
    await call('POST', '/mobile-workspace/messages', friend, { recipient: String(owner._id), body: 'Hello' });
    await wait(2); assert.equal(pushes[1].data.link, `/student/messages/${friend._id}`);
    await require('../src/models/ChatPreference').create({ user: owner._id, contact: friend._id, muted: true });
    await call('POST', '/mobile-workspace/messages', friend, { recipient: String(owner._id), body: 'Muted message' });
    assert.equal(await Notification.countDocuments({ user: owner._id }), 2);
    await User.updateOne({ _id: owner._id }, { $set: { 'notificationPreferences.community': false } });
    const next = await Story.create({ author: owner._id, operationId: 'push-muted-story', text: 'Story', expiresAt: new Date(Date.now() + 60000) });
    await call('POST', `/stories/${next._id}/love`, friend);
    await new Promise(r => setTimeout(r, 50));
    assert.equal(pushes.length, 2); assert.equal(await Notification.countDocuments({ user: owner._id }), 3, 'inbox keeps the event when push is disabled');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    global.fetch = nativeFetch;
    await mongoose.disconnect(); await mongo.stop();
  }
});
