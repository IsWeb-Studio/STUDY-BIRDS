const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('community inbox is private, ordered by latest message, and tracks bounded unread receipts', async () => {
  process.env.JWT_SECRET = 'community-test-only';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Friendship = require('../src/models/Friendship');
    const { Message, Session } = require('../src/models/MobileWorkspace');
    const Notification = require('../src/models/Notification');
    await Promise.all([User.init(), Friendship.init(), Message.init(), Session.init()]);
    const users = await User.create(Array.from({ length: 4 }, (_, i) => ({ name: `Chat Student ${i}`, email: `chat${i}@example.test`, role: 'student', isActive: true })));
    const app = express(); app.use(express.json()); app.use('/chat', require('../src/routes/mobileMessagingRoutes')); app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, user = 0, body) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/chat${route}`, { method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }, ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: response.status, data: await response.json() };
    }
    const send = (from, to, body) => call('POST', '/messages', from, { recipient: users[to].id, body });
    assert.equal((await send(0, 1, 'blocked')).status, 403);
    for (const i of [1, 2]) await Friendship.create({ _id: Friendship.pair(users[0]._id, users[i]._id), requester: users[0]._id, recipient: users[i]._id, status: 'accepted' });
    const first = await send(1, 0, 'first'); assert.equal(first.status, 201);
    await send(0, 2, 'second');
    const latest = await send(1, 0, 'latest');
    const inbox = (await call('GET', '/conversations')).data;
    assert.equal(inbox.conversations.length, 2);
    assert.equal(inbox.conversations[0].contact._id, users[1].id);
    assert.equal(inbox.conversations[0].lastMessage.body, 'latest');
    assert.equal(inbox.conversations[0].unreadCount, 2);
    assert.equal(inbox.unreadTotal, 2);
    assert.equal((await call('GET', '/conversations', 3)).data.conversations.length, 0);
    assert.equal((await call('GET', `/messages?recipient=${users[1].id}`, 3)).status, 403);
    assert.equal((await call('GET', '/conversations?before=invalid')).status, 400);
    assert.equal((await call('GET', `/contacts/${users[1].id}`)).data.name, users[1].name);
    assert.ok(await Notification.exists({ user: users[0]._id, link: `/student/messages/${users[1].id}` }));
    await call('POST', '/messages/read', 0, { sender: users[1].id, through: first.data._id });
    assert.equal((await call('GET', '/conversations?summary=1')).data.unreadTotal, 1);
    await call('POST', '/messages/read', 0, { sender: users[1].id, through: latest.data._id });
    assert.equal((await call('GET', '/conversations?summary=1')).data.unreadTotal, 0);
    await Friendship.deleteMany({});
    assert.equal((await send(1, 0, 'revoked')).status, 403);
    assert.equal((await call('GET', '/conversations')).data.conversations.length, 0);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
