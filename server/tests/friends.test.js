const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('friend requests are mutual and private; story access requires acceptance and ends on removal', async () => {
  process.env.JWT_SECRET = 'friends-isolated-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Friendship = require('../src/models/Friendship');
    const { Story, StoryStats, StoryInteraction } = require('../src/models/Stories');
    const { Session } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), Friendship.init(), Story.init(), StoryStats.init(), StoryInteraction.init(), Session.init()]);
    const users = await User.create(Array.from({ length: 5 }, (_, i) => ({ name: i === 3 ? 'Inactive Student' : `Friend Student ${i}`, email: `friend${i}@example.test`, role: i === 4 ? 'parent' : 'student', isActive: i !== 3 })));
    const story = await Story.create({ author: users[0]._id, text: 'Friends only', operationId: 'friend-story', expiresAt: new Date(Date.now() + 86400000) });
    const app = express(); app.use(express.json());
    app.use('/friends', require('../src/routes/friendRoutes'));
    app.use('/stories', require('../src/routes/storyRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, user = 0, body) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}${route}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user === null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }) },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      return { status: response.status, data: await response.json() };
    }
    const to = i => `/friends/${users[i]._id}`;
    assert.equal((await call('GET', '/friends', null)).status, 401);
    assert.equal((await call('GET', '/friends', 4)).status, 403);
    assert.equal((await call('GET', '/friends/search?q=F')).status, 400);
    const search = await call('GET', '/friends/search?q=Student');
    assert.equal(search.data.people.length, 2);
    assert.ok(search.data.people.every(p => !('email' in p) && !('phone' in p)));
    assert.equal((await call('GET', '/friends/search?q=%2E%2A')).data.people.length, 0, 'regex is escaped');
    assert.equal((await call('POST', `${to(0)}/request`)).status, 400);
    assert.equal((await call('POST', `${to(3)}/request`)).status, 404);
    assert.equal((await call('POST', `${to(4)}/request`)).status, 404);
    assert.equal((await call('GET', '/stories', 1)).data.stories.length, 0);
    assert.equal((await call('GET', '/stories', 0)).data.stories.length, 1);
    assert.equal((await call('POST', `/stories/${story.id}/seen`, 1)).status, 404);
    assert.equal((await call('POST', `/stories/${story.id}/love`, 1)).status, 404);
    assert.equal(await StoryInteraction.countDocuments(), 0);
    const requests = await Promise.all(Array.from({ length: 5 }, () => call('POST', `${to(1)}/request`, 0)));
    requests.forEach(r => assert.equal(r.status, 200));
    assert.equal(await Friendship.countDocuments(), 1);
    assert.equal((await call('GET', '/friends?kind=outgoing', 0)).data.people[0].relation, 'outgoing');
    assert.equal((await call('GET', '/friends?kind=incoming', 1)).data.people[0].relation, 'incoming');
    assert.equal((await call('POST', `${to(0)}/request`, 1)).data.relation, 'incoming', 'crossed requests require explicit acceptance');
    assert.equal((await call('POST', `${to(1)}/accept`, 0)).status, 404, 'sender cannot accept own request');
    assert.equal((await call('POST', `${to(0)}/accept`, 2)).status, 404);
    assert.equal((await call('GET', '/stories', 1)).data.stories.length, 0, 'pending is not a friend');
    assert.equal((await call('POST', `${to(0)}/accept`, 1)).status, 200);
    assert.equal((await call('POST', `${to(0)}/accept`, 1)).status, 200);
    for (const i of [0, 1]) assert.equal((await call('GET', '/friends', i)).data.people[0].relation, 'friends');
    assert.equal((await call('GET', '/stories', 1)).data.stories[0].id, story.id);
    assert.equal((await call('POST', `/stories/${story.id}/seen`, 1)).status, 200);
    assert.equal((await call('POST', `/stories/${story.id}/love`, 1)).status, 200);
    assert.equal((await StoryStats.findOne({ user: users[0]._id })).total_points, 50);
    assert.equal((await call('POST', `/stories/${story.id}/love`, 2)).status, 404, 'guessed id still private');
    await call('DELETE', to(1), 2); // Third party deletion cannot affect their friendship.
    assert.equal((await call('GET', '/stories', 1)).data.stories.length, 1);
    await call('DELETE', to(0), 1);
    assert.equal((await call('GET', '/stories', 1)).data.stories.length, 0);
    assert.equal((await call('POST', `/stories/${story.id}/seen`, 1)).status, 404);
    assert.equal((await call('POST', `/stories/${story.id}/love`, 1)).status, 404);
    assert.equal((await StoryStats.findOne({ user: users[0]._id })).total_points, 50, 'removal does not remove earned points');
    await call('POST', `${to(1)}/request`, 0);
    await call('DELETE', to(0), 1); // Decline.
    assert.equal((await call('GET', '/friends?kind=outgoing', 0)).data.people.length, 0);
    await call('POST', `${to(1)}/request`, 0);
    await call('DELETE', to(1), 0); // Cancel.
    assert.equal((await call('GET', '/friends?kind=incoming', 1)).data.people.length, 0);
    assert.equal((await call('GET', '/friends?kind=__proto__')).status, 400);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
