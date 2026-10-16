const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('chat images, unsend, private deletion and muting enforce participant ownership', async () => {
  process.env.JWT_SECRET = 'chat-controls-test-only';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Friendship = require('../src/models/Friendship');
    const Preference = require('../src/models/ChatPreference');
    const Notification = require('../src/models/Notification');
    const { Message, Session } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), Friendship.init(), Preference.init(), Message.init(), Session.init()]);
    const users = await User.create(Array.from({ length: 3 }, (_, i) => ({ name: `Chat Controls ${i}`, email: `controls${i}@example.test`, role: 'student', isActive: true })));
    await Friendship.create({ _id: Friendship.pair(users[0]._id, users[1]._id), requester: users[0]._id, recipient: users[1]._id, status: 'accepted' });
    let uploads = 0, downloads = 0;
    const images = require('../src/utils/chatImages');
    images.uploadChatImage = async () => { uploads++; return { publicId: 'private-test', format: 'jpg' }; };
    images.readChatImage = async () => { downloads++; return Buffer.from([0xff, 0xd8, 0xff, 0xd9]); };
    const app = express(); app.use(express.json()); app.use('/chat', require('../src/routes/mobileMessagingRoutes')); app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, user = 0, body) {
      const form = body instanceof FormData;
      const r = await fetch(`http://127.0.0.1:${server.address().port}/chat${route}`, {
        method, headers: { ...(form ? {} : { 'Content-Type': 'application/json' }), ...(user == null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }) },
        ...(body ? { body: form ? body : JSON.stringify(body) } : {}),
      });
      return { status: r.status, data: r.headers.get('content-type')?.includes('application/json') ? await r.json() : await r.arrayBuffer() };
    }
    const send = body => call('POST', '/messages', 0, { recipient: users[1].id, body });
    const thread = user => call('GET', `/messages?recipient=${users[1 - user].id}`, user);
    const chat = `/conversations/${users[0].id}`;
    const form = (recipient, type = 'image/jpeg', filename = 'photo.jpg', bytes = [0xff, 0xd8, 0xff, 0xd9]) => {
      const data = new FormData(); data.set('recipient', recipient); data.set('body', 'caption');
      data.set('operationId', 'photo-retry-123');
      data.set('file', new Blob([new Uint8Array(bytes)], { type }), filename); return data;
    };
    assert.equal((await call('POST', '/messages/image', 2, form(users[1].id))).status, 403);
    assert.equal(uploads, 0, 'unauthorized uploads never reach storage');
    assert.equal((await call('POST', '/messages/image', 0, form(users[1].id, 'image/jpeg', 'photo.jpg', [1, 2, 3]))).status, 415);
    assert.equal((await call('POST', '/messages/image', 0, form(users[1].id, 'text/plain', 'file.txt', [65, 66]))).status, 415);
    assert.equal(uploads, 0);
    const image = await call('POST', '/messages/image', 0, form(users[1].id));
    assert.equal(image.status, 201);
    assert.equal(image.data.body, 'caption');
    assert.ok(image.data.imagePath);
    assert.equal(image.data.image, undefined, 'storage identifiers stay private');
    const retry = await call('POST', '/messages/image', 0, form(users[1].id));
    assert.equal(retry.data._id, image.data._id); assert.equal(uploads, 1, 'retry does not upload or send twice');
    const imageRoute = `/messages/${image.data._id}/image`;
    assert.equal((await call('GET', imageRoute, null)).status, 401);
    assert.equal((await call('GET', imageRoute, 2)).status, 404);
    assert.equal(downloads, 0);
    assert.equal((await call('GET', imageRoute, 1)).status, 200);
    assert.equal((await call('GET', imageRoute, 0)).status, 200);
    assert.equal(downloads, 2);
    assert.equal((await call('DELETE', `/messages/${image.data._id}?scope=everyone`, 1)).status, 403);
    assert.equal((await call('DELETE', `/messages/${image.data._id}?scope=everyone`, 2)).status, 404);
    assert.equal((await call('DELETE', `/messages/${image.data._id}?scope=everyone`, 0)).status, 200);
    assert.equal((await call('GET', imageRoute, 1)).status, 404);
    const tombstone = (await thread(1)).data[0];
    assert.equal(tombstone.body, ''); assert.equal(tombstone.imagePath, null); assert.ok(tombstone.deletedAt);
    assert.equal((await call('GET', '/conversations?summary=1', 1)).data.unreadTotal, 0, 'unsent messages are not unread');
    const text = await send('only recipient hides this');
    assert.equal((await call('DELETE', `/messages/${text.data._id}?scope=me`, 1)).status, 200);
    assert.ok(!(await thread(1)).data.some(m => m._id === text.data._id));
    assert.ok((await thread(0)).data.some(m => m._id === text.data._id));
    assert.equal((await call('PUT', chat, 1, { muted: 'true' })).status, 400);
    assert.equal((await call('PUT', chat, 1, { muted: true })).data.muted, true);
    const notifications = await Notification.countDocuments({ user: users[1]._id });
    await send('silent message');
    assert.equal(await Notification.countDocuments({ user: users[1]._id }), notifications, 'muted chat generates no notification/push');
    const mutedInbox = (await call('GET', '/conversations', 1)).data;
    assert.equal(mutedInbox.unreadTotal, 0);
    assert.equal(mutedInbox.conversations[0].muted, true);
    assert.equal(mutedInbox.conversations[0].unreadCount, 1, 'muted chats retain their own unread badge');
    assert.equal((await call('GET', `/conversations/${users[1].id}`, 0)).data.muted, false, 'mute is personal');
    assert.equal((await call('PUT', chat, 1, { muted: false })).data.muted, false);
    assert.equal((await call('GET', '/conversations?summary=1', 1)).data.unreadTotal, 1);
    const activeForm = form(users[1].id); activeForm.set('operationId', 'active-photo-123');
    const active = await call('POST', '/messages/image', 0, activeForm);
    assert.equal(active.status, 201);
    const activeRoute = `/messages/${active.data._id}/image`;
    assert.equal((await call('GET', activeRoute, 1)).status, 200);
    assert.equal((await call('DELETE', chat, 1)).status, 200);
    assert.equal((await call('GET', activeRoute, 1)).status, 404);
    assert.equal((await call('GET', activeRoute, 0)).status, 200);
    assert.equal((await thread(1)).data.length, 0);
    assert.equal((await call('GET', '/conversations', 1)).data.conversations.length, 0);
    assert.ok((await thread(0)).data.length > 0, 'clearing never erases the other participant history');
    assert.equal((await call('GET', imageRoute, 1)).status, 404);
    await send('new conversation after clear');
    assert.deepEqual((await thread(1)).data.map(m => m.body), ['new conversation after clear']);
    assert.equal((await call('GET', '/conversations', 1)).data.conversations[0].lastMessage.body, 'new conversation after clear');
    assert.equal((await call('GET', `/messages?recipient=${users[0].id}&ids=${text.data._id}`, 1)).data.length, 0, 'id refresh cannot bypass hidden history');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
