const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('community stories include non-friends, paginate, and exclude expired or unavailable authors', async () => {
  process.env.JWT_SECRET = 'community-stories-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const { Story, StoryStats, StoryInteraction } = require('../src/models/Stories');
    const { Session } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), Story.init(), StoryStats.init(), StoryInteraction.init(), Session.init()]);
    const users = await User.create(Array.from({ length: 4 }, (_, i) => ({ name: `Published Student ${i}`, email: `published${i}@example.test`, role: i === 3 ? 'parent' : 'student', isActive: i !== 2 })));
    const active = await Story.create(Array.from({ length: 65 }, (_, i) => ({ author: users[1]._id, operationId: `community-${i}`, text: `published-${i}`, expiresAt: new Date(Date.now() + 86400000) })));
    const excluded = await Story.create([
      { author: users[1]._id, operationId: 'expired', text: 'expired', expiresAt: new Date(Date.now() - 1000) },
      { author: users[2]._id, operationId: 'inactive', text: 'inactive', expiresAt: new Date(Date.now() + 86400000) },
      { author: users[3]._id, operationId: 'parent', text: 'parent', expiresAt: new Date(Date.now() + 86400000) },
    ]);
    const app = express(); app.use(express.json()); app.use('/stories', require('../src/routes/storyRoutes')); app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route = '', user = 0) {
      const r = await fetch(`http://127.0.0.1:${server.address().port}/stories${route}`, { method, headers: { 'Content-Type': 'application/json', ...(user == null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }) } });
      return { status: r.status, data: await r.json() };
    }
    assert.equal((await call('GET', '', null)).status, 401);
    assert.equal((await call('GET', '', 3)).status, 403);
    const first = (await call('GET')).data;
    assert.equal(first.stories.length, 60);
    assert.ok(first.stories.every(s => s.author.id === users[1].id));
    const second = (await call('GET', `?before=${first.nextCursor}`)).data;
    assert.equal(second.stories.length, 5); assert.equal(second.nextCursor, null);
    assert.ok(second.stories.every(s => !first.stories.some(p => p.id === s.id)));
    const visible = active.at(-1).id;
    assert.equal((await call('POST', `/${visible}/seen`)).status, 200);
    assert.equal((await call('POST', `/${visible}/love`)).status, 200);
    assert.equal((await call('POST', `/${visible}/love`)).status, 200);
    const update = (await call('GET', `/updates?ids=${[visible, ...excluded.map(s => s.id)].join(',')}`)).data;
    assert.equal(update.updates.length, 1); assert.equal(update.updates[0].loved, true);
    assert.equal((await StoryStats.findOne({ user: users[1]._id })).total_points, 50, 'public love still awards once');
    for (const story of excluded) assert.equal((await call('POST', `/${story.id}/seen`)).status, 404);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
