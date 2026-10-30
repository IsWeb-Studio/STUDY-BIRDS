const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const voice = require('../src/utils/voiceNotes');
const box = (name, ...parts) => {
  const payload = Buffer.concat(parts); const header = Buffer.alloc(8);
  header.writeUInt32BE(payload.length + 8); header.write(name, 4);
  return Buffer.concat([header, payload]);
};
function container(handler = 'soun') {
  return Buffer.concat([box('ftyp', Buffer.from('M4A \0\0\0\0')),
    box('moov', box('trak', box('mdia', box('hdlr', Buffer.alloc(8), Buffer.from(handler))))),
    box('mdat', Buffer.from([1, 2, 3]))]);
}
const file = buffer => ({ buffer, originalname: 'voice.m4a', mimetype: 'audio/mp4' });
test('voice container rejects spoofed, truncated, oversized and video files', () => {
  assert.doesNotThrow(() => voice.validateVoice(file(container())));
  for (const bytes of [Buffer.from('not audio'), container('vide'), container().subarray(0, 25), Buffer.alloc(voice.MAX_BYTES + 1)]) {
    assert.throws(() => voice.validateVoice(file(bytes)));
  }
  assert.throws(() => voice.validateVoice({ ...file(container()), mimetype: 'image/jpeg' }));
});

test('voice chats and tickets enforce access, retries, closed status and private metadata', async () => {
  process.env.JWT_SECRET = 'voice-test-only';
  const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Friendship = require('../src/models/Friendship');
    const Ticket = require('../src/models/SupportTicket');
    const { Message } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), Friendship.init(), Message.init(), Ticket.init()]);
    const users = await User.create(['student', 'student', 'student', 'admin', 'parent', 'university', 'employee'].map((role, i) => ({ name: `Voice ${i}`, email: `voice${i}@example.test`, role, isActive: true })));
    await Friendship.create({ _id: Friendship.pair(users[0]._id, users[1]._id), requester: users[0]._id, recipient: users[1]._id, status: 'accepted' });
    let uploads = 0, reads = 0, removals = 0;
    voice.uploadVoice = async () => ({ publicId: `private-${++uploads}`, format: 'm4a', duration: 2, resourceType: 'video', deliveryType: 'authenticated' });
    voice.readVoice = async () => { reads++; return container(); };
    voice.removeVoice = async () => { removals++; };
    const app = express(); app.use(express.json());
    app.use('/chat', require('../src/routes/mobileMessagingRoutes'));
    app.use('/voice', require('../src/routes/voiceRoutes'));
    process.env.CLOUDINARY_CLOUD_NAME = 'story-test';
    require('../src/utils/uploadToCloudinary').uploadFileToCloudinary = async (_, folder) => ({ url: `https://res.cloudinary.com/story-test/image/upload/${folder}/photo.jpg` });
    app.use('/stories', require('../src/routes/storyRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const call = async (method, route, user, body) => {
      const response = await fetch(`http://127.0.0.1:${server.address().port}${route}`, {
        method, headers: { ...(user == null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }), ...(typeof body === 'string' ? { 'Content-Type': 'application/json' } : {}) }, body,
      });
      return { status: response.status, data: response.headers.get('content-type')?.includes('application/json') ? await response.json() : await response.arrayBuffer() };
    };
    const form = (operation = 'voice-operation-123') => {
      const data = new FormData(); data.set('recipient', users[1].id); data.set('community', 'true'); data.set('operationId', operation);
      data.set('file', new Blob([container()], { type: 'audio/mp4' }), 'voice.m4a'); return data;
    };
    const denied = form(); denied.set('recipient', users[2].id);
    assert.equal((await call('POST', '/chat/messages/audio', 2, denied)).status, 403);
    assert.equal(uploads, 0);
    const sent = await call('POST', '/chat/messages/audio', 0, form());
    assert.equal(sent.status, 201); assert.ok(sent.data.audioPath); assert.equal(sent.data.audio, undefined);
    const retry = await call('POST', '/chat/messages/audio', 0, form());
    assert.equal(retry.data._id, sent.data._id); assert.equal(uploads, 1);
    const route = `/chat/messages/${sent.data._id}/audio?community=1`;
    assert.equal((await call('GET', route, null)).status, 401);
    assert.equal((await call('GET', route, 2)).status, 404); assert.equal(reads, 0);
    assert.equal((await call('GET', route, 1)).status, 200);
    assert.equal((await call('DELETE', `/chat/messages/${sent.data._id}?scope=everyone&community=1`, 1)).status, 403);
    assert.equal((await call('DELETE', `/chat/messages/${sent.data._id}?scope=everyone`, 0)).status, 200);
    assert.equal(removals, 1); assert.equal((await call('GET', route, 1)).status, 404);
    const ticket = await Ticket.create({ user: users[0]._id, requesterRole: 'student', subject: 'Voice ticket', message: 'Help' });
    const post = `/voice/tickets/${ticket.id}/replies`;
    assert.equal((await call('POST', post, 2, form())).status, 403); assert.equal(uploads, 1);
    const reply = await call('POST', post, 0, form());
    assert.equal(reply.status, 201);
    assert.equal(reply.data.replies[0].audioStorage, undefined, 'storage IDs never leave API');
    assert.equal((await call('POST', post, 0, form())).data.replies.length, 1); assert.equal(uploads, 2);
    const audio = reply.data.replies[0].audioPath;
    assert.equal((await call('GET', audio, 2)).status, 403);
    assert.equal((await call('GET', audio, 3)).status, 200);
    assert.equal((await call('GET', audio, 0)).status, 200);
    assert.equal((await Ticket.findById(ticket.id)).replies[0].audioStorage, undefined);
    assert.ok((await Ticket.findById(ticket.id).select('+replies.audioStorage')).replies[0].audioStorage.publicId);
    await Ticket.updateOne({ _id: ticket._id }, { $set: { status: 'closed' } });
    assert.equal((await call('POST', post, 0, form('closed-voice-123'))).status, 400); assert.equal(uploads, 2);
    for (const index of [0, 4, 5, 6]) {
      const image = new FormData();
      image.set('file', new Blob([new Uint8Array([255, 216, 255, 217])], { type: 'image/jpeg' }), 'photo.jpg');
      const uploaded = await call('POST', '/stories/image', index, image);
      assert.equal(uploaded.status, 200, `${users[index].role} image upload`);
      const body = JSON.stringify({ text: '', imageUrl: uploaded.data.imageUrl, operationId: `direct-story-${index}` });
      const published = await call('POST', '/stories', index, body);
      assert.equal(published.status, 201, `${users[index].role} direct publish`);
      assert.equal(published.data.awarded, index === 0 ? 100 : 0);
      assert.equal((await call('POST', '/stories', index, body)).data.id, published.data.id);
      assert.ok((await call('GET', '/stories', index)).data.stories.some(story => story.id === published.data.id));
    }
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
