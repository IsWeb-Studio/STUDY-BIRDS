const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('public student profiles expose only public fields, published community stories, and direct student messaging', async () => {
  process.env.JWT_SECRET = 'student-profiles-test-only';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Friendship = require('../src/models/Friendship');
    const { Story, StoryStats, StoryInteraction } = require('../src/models/Stories');
    const { Session } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), Friendship.init(), Story.init(), StoryStats.init(), StoryInteraction.init(), Session.init()]);
    const users = await User.create(Array.from({ length: 5 }, (_, i) => ({ name: `Profile Student ${i}`, email: `private-profile${i}@example.test`, role: i === 3 ? 'parent' : 'student', isActive: i !== 4,
      verifiedPhone: 'private-phone', crmIdentity: { companyId: 'private-company', recordId: `private-crm-${i}` } })));
    await StoryStats.create({ user: users[1]._id, total_points: 200000, streak_days: 21, lastStoryAt: new Date(Date.now() - 37 * 3600000) });
    const stories = await Story.create(Array.from({ length: 34 }, (_, i) => ({ author: users[1]._id, operationId: `profile-${i}`, text: `story-${i}`, expiresAt: new Date(Date.now() + 86400000) })));
    await Story.create({ author: users[1]._id, operationId: 'expired-profile', text: 'expired', expiresAt: new Date(Date.now() - 1000) });
    await StoryInteraction.create({ story: stories[33]._id, user: users[0]._id, seenAt: new Date(), lovedAt: new Date() });
    const app = express(); app.use(express.json());
    app.use('/friends', require('../src/routes/friendRoutes')); app.use('/chat', require('../src/routes/mobileMessagingRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, user = 0, body) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}${route}`, { method, headers: { 'Content-Type': 'application/json', ...(user == null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }) }, ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: response.status, data: await response.json() };
    }
    const profile = `/friends/${users[1].id}/profile`;
    assert.equal((await call('GET', profile, null)).status, 401);
    assert.equal((await call('GET', profile, 3)).status, 403);
    assert.equal((await call('GET', '/friends/invalid/profile')).status, 400);
    assert.equal((await call('GET', `/friends/${users[4].id}/profile`)).status, 404);
    assert.equal((await call('GET', `/friends/${users[3].id}/profile`)).status, 404);
    const publicProfile = (await call('GET', profile)).data;
    assert.equal(publicProfile.name, users[1].name);
    assert.equal(publicProfile.relation, 'none'); assert.equal(publicProfile.canMessage, true);
    assert.equal(publicProfile.total_points, 200000); assert.equal(publicProfile.streak_days, 0, 'expired streak is calculated on read');
    assert.equal(publicProfile.stories.length, 30); assert.equal(publicProfile.storyCount, 34); assert.equal(publicProfile.canViewStories, true);
    assert.ok(!JSON.stringify(publicProfile).includes('private-'), 'email, phone and CRM fields never leave the server');
    const own = (await call('GET', `/friends/${users[0].id}/profile`)).data;
    assert.equal(own.relation, 'self'); assert.equal(own.canMessage, false); assert.equal(own.canViewStories, true);
    const message = await call('POST', '/chat/messages', 0, { recipient: users[1].id, body: 'hello from your public profile' });
    assert.equal(message.status, 201);
    const inbox = (await call('GET', '/chat/conversations', 1)).data;
    assert.equal(inbox.conversations[0].contact._id, users[0].id);
    assert.equal(inbox.unreadTotal, 1, 'messages from non-friends appear in the inbox');
    assert.deepEqual((await call('GET', `/chat/messages?recipient=${users[1].id}`, 2)).data, [], 'third party cannot read another conversation');
    await call('POST', `/friends/${users[1].id}/request`);
    assert.equal((await call('GET', profile)).data.relation, 'outgoing');
    assert.equal((await call('GET', `/friends/${users[0].id}/profile`, 1)).data.relation, 'incoming');
    assert.equal((await call('GET', profile)).data.canViewStories, true);
    await call('POST', `/friends/${users[0].id}/accept`, 1);
    const friend = (await call('GET', profile)).data;
    assert.equal(friend.relation, 'friends'); assert.equal(friend.friendCount, 1);
    assert.equal(friend.storyCount, 34); assert.equal(friend.stories.length, 30);
    assert.ok(friend.stories.every(s => s.author.id === users[1].id && s.text !== 'expired'));
    assert.equal(friend.stories[0].seen, true); assert.equal(friend.stories[0].loved, true);
    const next = (await call('GET', `${profile}?before=${friend.nextStoriesCursor}`)).data;
    assert.equal(next.stories.length, 4); assert.equal(next.nextStoriesCursor, null);
    assert.ok(next.stories.every(s => !friend.stories.some(old => old.id === s.id)));
    await call('DELETE', `/friends/${users[1].id}`);
    assert.equal((await call('GET', profile)).data.canViewStories, true);
    assert.equal((await call('GET', `${profile}?before=${friend.nextStoriesCursor}`)).data.stories.length, 4, 'published stories remain available after unfriending');
    assert.equal((await call('POST', '/chat/messages', 0, { recipient: users[1].id, body: 'still a conversation' })).status, 201);
    await User.updateOne({ _id: users[1]._id }, { $set: { isActive: false } });
    assert.equal((await call('GET', profile)).status, 404);
    assert.equal((await call('POST', '/chat/messages', 0, { recipient: users[1].id, body: 'unavailable' })).status, 403);
    assert.equal((await call('GET', '/chat/conversations')).data.conversations.length, 0);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
