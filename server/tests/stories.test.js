const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('stories: authorization, concurrent rewards, durable replay, seen, expiry and point preservation', async () => {
  process.env.JWT_SECRET = 'stories-local-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  const media = require('../src/utils/uploadToCloudinary');
  const originalUpload = media.uploadFileToCloudinary;
  try {
    process.env.CLOUDINARY_CLOUD_NAME = 'stories-test';
    let uploadedFolder;
    media.uploadFileToCloudinary = async (file, folder) => {
      assert.equal(file.mimetype, 'image/png'); uploadedFolder = folder;
      return { url: `https://res.cloudinary.com/stories-test/image/upload/v123/${folder}/photo.png` };
    };
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const { Story, StoryStats, StoryInteraction } = require('../src/models/Stories');
    const { Session } = require('../src/models/MobileWorkspace');
    const Friendship = require('../src/models/Friendship');
    await Promise.all([User.init(), Story.init(), StoryStats.init(), StoryInteraction.init(), Session.init(), Friendship.init()]);
    const users = await User.create(Array.from({ length: 14 }, (_, i) => ({ name: `Story user ${i}`, email: `story${i}@example.test`, role: i === 12 ? 'parent' : i === 13 ? 'admin' : 'student' })));
    const friends = [];
    for (let a = 0; a < 12; a++) for (let b = a + 1; b < 12; b++) friends.push({ _id: Friendship.pair(users[a]._id, users[b]._id), requester: users[a]._id, recipient: users[b]._id, status: 'accepted' });
    await Friendship.insertMany(friends);
    const app = express(); app.use(express.json()); app.use('/stories', require('../src/routes/storyRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    let serial = 0;
    async function call(method, route, user = 0, body) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/stories${route}`, {
        method, headers: { 'Content-Type': 'application/json', ...(user === null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }) },
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await response.json(); return { status: response.status, data };
    }
    const post = (user = 0, operationId = `test-story-${++serial}`) => call('POST', '', user, { text: 'Today I studied', operationId });
    assert.equal((await call('GET', '', null)).status, 401);
    assert.equal((await call('GET', '', 12)).status, 403);
    assert.equal((await call('POST', '', 0, { text: 'bad' })).status, 400);
    assert.equal((await call('POST', '', 0, { text: '', operationId: 'empty-test' })).status, 400);
    assert.equal((await call('POST', '', 0, { text: 'bad image', operationId: 'bad-image-test', imageUrl: 'https://example.com/photo.png' })).status, 400);
    const adminStory = await call('POST', '', 13, { text: 'Official update', audience: 'students', operationId: 'admin-story-points-01' });
    assert.equal(adminStory.status, 201, JSON.stringify(adminStory));
    assert.equal(adminStory.data.awarded, 100, 'the first community story of the day earns points');
    assert.equal(adminStory.data.progress.total_points, 100);
    assert.equal(adminStory.data.progress.streak_days, 0, 'an admin story does not advance the game-based streak');
    const adminStats = await StoryStats.findOne({ user: users[13]._id }).lean();
    assert.equal(adminStats.gameStreakDays || 0, 0);
    const adminExtra = await call('POST', '', 13, { text: 'Second update', audience: 'students', operationId: 'admin-story-points-02' });
    assert.equal(adminExtra.data.awarded, 0, 'additional stories on the same day do not farm points');
    assert.equal((await call('GET', '/progress', 13)).data.total_points, 100);
    const repeated = await Promise.all(Array.from({ length: 4 }, () => post(0, 'same-operation')));
    for (const response of repeated) assert.equal(response.status, 201, JSON.stringify(response));
    assert.equal(await Story.countDocuments(), 1);
    assert.equal((await call('GET', '/progress')).data.total_points, 100);
    const id = repeated[0].data.id;
    const extra = await Promise.all([post(), post()]);
    extra.forEach(r => assert.equal(r.status, 201));
    assert.equal((await call('GET', '/progress')).data.streak_days, 1);
    const selfLoves = await Promise.all(Array.from({ length: 4 }, () => call('POST', `/${id}/love`, 0)));
    selfLoves.forEach(r => { assert.equal(r.status, 200); assert.equal(r.data.awarded, 0); });
    assert.equal((await Story.findById(id)).loveCount, 1);
    const selfProgress = (await call('GET', '/progress', 0)).data;
    assert.equal(selfProgress.total_points, 100);
    assert.equal(selfProgress.dailyLoveCount, 0);
    const loves = await Promise.all(Array.from({ length: 5 }, () => call('POST', `/${id}/love`, 1)));
    loves.forEach(r => assert.equal(r.status, 200, JSON.stringify(r)));
    assert.equal((await Story.findById(id)).loveCount, 2);
    assert.equal((await call('GET', '/progress', 0)).data.total_points, 150);
    assert.equal((await call('GET', '/progress', 1)).data.total_points, 5);
    const different = await Promise.all([2, 3, 4, 5].map(i => call('POST', `/${id}/love`, i)));
    different.forEach(r => assert.equal(r.status, 200));
    assert.equal((await call('GET', '/progress')).data.total_points, 350);
    let feed = await call('GET', '', 1);
    assert.equal(feed.data.stories.find(s => s.id === id).seen, false);
    assert.equal((await call('POST', `/${id}/seen`, 1)).status, 200);
    feed = await call('GET', '', 1);
    assert.equal(feed.data.stories.find(s => s.id === id).seen, true);
    assert.equal(feed.data.stories.find(s => s.id === id).loved, true);
    assert.equal((await call('GET', '', 2)).data.stories.find(s => s.id === id).seen, false);
    // Eleven distinct new stories; cap is global across authors/stories.
    const more = [];
    for (let i = 0; i < 11; i++) { const r = await post(i % 2 === 0 ? 0 : 2); assert.equal(r.status, 201); more.push(r.data.id); }
    const capped = await Promise.all(more.map(story => call('POST', `/${story}/love`, 1)));
    capped.forEach(r => assert.equal(r.status, 200, JSON.stringify(r)));
    assert.equal((await call('GET', '/progress', 1)).data.total_points, 50);
    assert.equal((await call('GET', '/progress', 1)).data.dailyLoveCount, 10);
    const before = (await call('GET', '/progress')).data.total_points;
    await StoryStats.updateOne({ user: users[0]._id }, { $set: { lastStoryAt: new Date(Date.now() - 37 * 3600000), streak_days: 7 } });
    const reset = (await call('GET', '/progress')).data;
    assert.equal(reset.streak_days, 0); assert.equal(reset.total_points, before);
    assert.equal((await StoryStats.findOne({ user: users[0]._id })).streak_days, 0);
    assert.equal(reset.recoverableStreakDays, 7);
    const restores = await Promise.all(Array.from({ length: 5 }, () => call('POST', '/streak/restore')));
    assert.equal(restores.filter(r => r.status === 200).length, 1, 'concurrent restore consumes one allowance');
    assert.equal((await call('GET', '/progress')).data.streakRestoresRemaining, 2);
    assert.equal((await call('GET', '/progress')).data.total_points, before);
    for (let attempt = 2; attempt <= 4; attempt++) {
      await StoryStats.updateOne({ user: users[0]._id }, { $set: { lastStoryAt: new Date(Date.now() - 37 * 3600000) } });
      const result = await call('POST', '/streak/restore');
      assert.equal(result.status, attempt <= 3 ? 200 : 409);
    }
    assert.equal((await call('GET', '/progress')).data.streak_days, 0);
    assert.equal((await call('POST', '/streak/restore', 12)).status, 403);
    await Story.updateOne({ _id: id }, { $set: { expiresAt: new Date(Date.now() - 1) } });
    assert.equal((await call('POST', `/${id}/love`, 6)).status, 404);
    assert.equal((await call('POST', `/${id}/seen`, 6)).status, 404);
    assert.equal((await call('GET', '', 6)).data.stories.some(s => s.id === id), false);
    await post(0, 'same-operation'); // Replay does not recreate expired story or award points.
    assert.equal((await call('GET', '/progress')).data.total_points, before);
    // Different first-time actions racing on a fresh edge preserve both flags.
    const freshId = extra[0].data.id;
    const racing = await Promise.all([
      call('POST', `/${freshId}/seen`, 7), call('POST', `/${freshId}/seen`, 7), call('POST', `/${freshId}/love`, 7),
    ]);
    racing.forEach(r => assert.equal(r.status, 200, JSON.stringify(r)));
    const edge = await StoryInteraction.findOne({ story: freshId, user: users[7]._id });
    assert.ok(edge.seenAt); assert.ok(edge.lovedAt);
    // Real multipart parsing and image signature validation; only external storage is mocked.
    const form = new FormData();
    form.append('file', new Blob([Buffer.from('89504e470d0a1a0a00000000', 'hex')], { type: 'image/png' }), 'photo.png');
    const uploaded = await fetch(`http://127.0.0.1:${server.address().port}/stories/image`, {
      method: 'POST', headers: { Authorization: `Bearer ${jwt.sign({ userId: users[8]._id }, process.env.JWT_SECRET)}` }, body: form,
    });
    assert.equal(uploaded.status, 200); const image = await uploaded.json();
    assert.equal(uploadedFolder, `story-images/${users[8]._id}`);
    const photo = await call('POST', '', 8, { operationId: 'photo-story-test', imageUrl: image.imageUrl });
    assert.equal(photo.status, 201, JSON.stringify(photo));
    assert.equal(photo.data.awarded, 100);
    assert.equal((await call('GET', '', 9)).data.stories.find(s => s.id === photo.data.id).imageUrl, image.imageUrl);
    assert.equal((await call('POST', '', 9, { operationId: 'stolen-photo-test', imageUrl: image.imageUrl })).status, 400);
    const balance = (await call('GET', '/progress', 8)).data.total_points;
    assert.equal((await call('GET', '/progress', 8)).data.scoreEmoji, '🔥');
    const preference = await call('PUT', '/preferences', 8, { scoreEmoji: '💎', total_points: 999999 });
    assert.equal(preference.status, 200); assert.equal(preference.data.scoreEmoji, '💎');
    assert.equal(preference.data.total_points, balance);
    assert.equal((await call('GET', '/progress', 8)).data.scoreEmoji, '💎');
    assert.equal((await call('GET', '/progress', 9)).data.scoreEmoji, '🔥');
    assert.equal((await call('PUT', '/preferences', 8, { scoreEmoji: '<script>' })).status, 400);
    assert.equal((await call('PUT', '/preferences', 12, { scoreEmoji: '⭐' })).status, 403);
    // Only the owner can delete; the tombstone prevents reward replay and keeps balances.
    const photoId = photo.data.id;
    assert.equal((await call('DELETE', `/${photoId}`, 9)).status, 404);
    assert.equal((await call('DELETE', `/${photoId}`, 8)).status, 200);
    assert.equal((await call('DELETE', `/${photoId}`, 8)).status, 200);
    assert.equal((await call('GET', '', 9)).data.stories.some(s => s.id === photoId), false);
    assert.equal((await call('POST', `/${photoId}/love`, 9)).status, 404);
    assert.equal((await call('POST', `/${photoId}/seen`, 9)).status, 404);
    assert.equal((await call('GET', `/updates?ids=${photoId}`, 9)).data.updates.length, 0);
    assert.ok((await Story.findById(photoId)).deletedAt);
    assert.ok(await require('../src/models/MaintenanceJob').exists({ publicId: `story-images/${users[8]._id}/photo` }));
    assert.equal((await call('POST', '', 8, { operationId: 'photo-story-test', text: 'Replay' })).data.awarded, 0);
    assert.equal((await call('GET', '/progress', 8)).data.total_points, balance);
  } finally {
    media.uploadFileToCloudinary = originalUpload;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
