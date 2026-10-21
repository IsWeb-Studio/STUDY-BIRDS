const test = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const path = require('node:path');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('only story owner sees unique viewers, with complete pagination and no self/love-only counts', async () => {
  process.env.JWT_SECRET = 'story-viewers-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } }); let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const { Story, StoryInteraction } = require('../src/models/Stories');
    await StoryInteraction.init();
    const users = await User.insertMany(Array.from({ length: 56 }, (_, i) => ({ name: `Viewer ${i}`, email: `viewer${i}@example.test`, role: 'student', isActive: true })));
    const story = await Story.create({ author: users[0]._id, operationId: 'viewers-test', text: 'Hello', expiresAt: new Date(Date.now() + 3600000) });
    const app = express(); app.use(express.json()); app.use('/stories', require('../src/routes/storyRoutes')); app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const call = async (route, user = 0, method = 'GET') => {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/stories${route}`, { method, headers: { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` } });
      return { status: response.status, data: await response.json() };
    };
    assert.equal((await call(`/${story.id}/viewers`)).data.total, 0);
    await Promise.all([call(`/${story.id}/seen`, 1, 'POST'), call(`/${story.id}/seen`, 1, 'POST'), call(`/${story.id}/seen`, 1, 'POST')]);
    await call(`/${story.id}/seen`, 0, 'POST');
    await StoryInteraction.insertMany(users.slice(2, 54).map(user => ({ story: story._id, user: user._id, seenAt: new Date() })));
    await StoryInteraction.create({ story: story._id, user: users[54]._id, lovedAt: new Date() });
    await User.updateOne({ _id: users[3]._id }, { isActive: false });
    const first = await call(`/${story.id}/viewers`);
    assert.equal(first.status, 200); assert.equal(first.data.total, 53); assert.equal(first.data.viewers.length, 50);
    const second = await call(`/${story.id}/viewers?before=${first.data.nextCursor}`);
    assert.equal(second.data.total, 53); assert.equal(second.data.viewers.length, 3); assert.equal(second.data.nextCursor, null);
    const all = [...first.data.viewers, ...second.data.viewers];
    assert.equal(all.filter(user => user.id === users[1].id).length, 1);
    assert.equal(all.filter(user => user.id === null).length, 1);
    assert.equal(all.some(user => user.id === users[0].id || user.id === users[54].id), false);
    assert.equal(all.some(user => user.email !== undefined), false);
    assert.equal((await call(`/${story.id}/viewers`, 55)).status, 404);
    assert.equal((await call(`/${story.id}/viewers?before=bad`)).status, 400);
    assert.equal((await call(`/${story.id}/viewers?before=${story.id}&before=${story.id}`)).status, 400);
    assert.equal((await call('')).data.stories[0].viewCount, 53);
    assert.equal((await call('', 55)).data.stories[0].viewCount, undefined);
    assert.equal((await call(`/updates?ids=${story.id}`)).data.updates[0].viewCount, 53);
    assert.equal((await call(`/updates?ids=${story.id}`, 55)).data.updates[0].viewCount, undefined);
    await Story.updateOne({ _id: story._id }, { expiresAt: new Date(Date.now() - 1) });
    assert.equal((await call(`/${story.id}/viewers`)).status, 404);
  } finally { if (server) await new Promise(resolve => server.close(resolve)); await mongoose.disconnect(); await mongo.stop(); }
});
