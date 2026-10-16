const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('compact inbox paginates without losing unread totals or truncating actual messages', async () => {
  process.env.JWT_SECRET = 'inbox-pages-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const { Message, Session } = require('../src/models/MobileWorkspace');
    const Preference = require('../src/models/ChatPreference');
    await Promise.all([User.init(), Message.init(), Session.init(), Preference.init()]);
    const users = await User.create(Array.from({ length: 37 }, (_, i) => ({ name: `Inbox Student ${i}`, email: `inbox-pages-${i}@example.test`, role: 'student', isActive: true })));
    const body = 'A'.repeat(4000);
    await Message.create(users.slice(1).flatMap((user, i) => Array.from({ length: 3 }, (_, j) => ({ sender: user._id, recipient: users[0]._id, body, createdAt: new Date(Date.now() - (36 - i) * 1000 + j) }))));
    const app = express(); app.use(express.json()); app.use('/chat', require('../src/routes/mobileMessagingRoutes')); app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function get(route) {
      const r = await fetch(`http://127.0.0.1:${server.address().port}/chat${route}`, { headers: { Authorization: `Bearer ${jwt.sign({ userId: users[0]._id }, process.env.JWT_SECRET)}` } });
      assert.equal(r.status, 200); return r.json();
    }
    const first = await get('/conversations');
    assert.equal(first.conversations.length, 30); assert.equal(first.unreadTotal, 108);
    assert.ok(JSON.stringify(first).length < 30000, 'inbox downloads previews instead of whole 4000-character messages');
    assert.ok(first.conversations.every(row => row.lastMessage.body.length === 160));
    const second = await get(`/conversations?before=${encodeURIComponent(first.nextCursor)}`);
    assert.equal(second.conversations.length, 6); assert.equal(second.unreadTotal, 108); assert.equal(second.nextCursor, null);
    assert.ok(second.conversations.every(row => !first.conversations.some(old => old.contact._id === row.contact._id)));
    const history = await get(`/messages?recipient=${first.conversations[0].contact._id}`);
    assert.equal(history[0].body, body, 'only previews are shortened');
    await Preference.create({ user: users[0]._id, contact: users[36]._id, muted: true });
    assert.equal((await get('/conversations?summary=1')).unreadTotal, 105);
    assert.equal((await get('/conversations')).unreadTotal, 105);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
