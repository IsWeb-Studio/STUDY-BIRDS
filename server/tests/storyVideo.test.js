const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('video story upload validates media, ownership, metadata and existing reward limits', async () => {
  process.env.JWT_SECRET = 'story-video-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  const videoUpload = require('../src/utils/storyVideoUpload');
  const original = videoUpload.uploadStoryVideo;
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const StoryVideo = require('../src/models/StoryVideo');
    const { Story, StoryStats, StoryInteraction } = require('../src/models/Stories');
    const Friendship = require('../src/models/Friendship');
    const { Session } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), StoryVideo.init(), Story.init(), StoryStats.init(), StoryInteraction.init(), Friendship.init(), Session.init()]);
    const users = await User.create([0, 1].map(i => ({ name: `Video ${i}`, email: `video${i}@example.test`, role: 'student' })));
    let uploads = 0;
    videoUpload.uploadStoryVideo = async (file, owner) => {
      uploads++; assert.equal(file.mimetype, 'video/mp4');
      return { videoUrl: `https://res.cloudinary.com/test/video/upload/story-videos/${owner}/clip.mp4`, duration: 12.5 };
    };
    const app = express(); app.use(express.json()); app.use('/stories', require('../src/routes/storyRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/stories`;
    const auth = i => ({ Authorization: `Bearer ${jwt.sign({ userId: users[i]._id }, process.env.JWT_SECRET)}` });
    async function upload(bytes, name = 'clip.mp4', type = 'video/mp4') {
      const form = new FormData(); form.append('file', new Blob([bytes], { type }), name);
      const r = await fetch(base + '/video', { method: 'POST', headers: auth(0), body: form });
      return { status: r.status, data: await r.json() };
    }
    async function post(body, i = 0) {
      const r = await fetch(base, { method: 'POST', headers: { ...auth(i), 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      return { status: r.status, data: await r.json() };
    }
    assert.equal((await upload(Buffer.from('fake video'))).status, 415);
    assert.equal((await upload(Buffer.from('89504e470d0a1a0a', 'hex'), 'photo.png', 'image/png')).status, 415);
    const asset = await upload(Buffer.from('000000146674797069736f6d00000000', 'hex'));
    assert.equal(asset.status, 200, JSON.stringify(asset)); assert.equal(uploads, 1);
    assert.equal((await StoryVideo.findOne({ owner: users[0]._id })).duration, 12.5);
    assert.equal((await post({ operationId: 'stolen-video', videoUrl: asset.data.videoUrl }, 1)).status, 400);
    assert.equal((await post({ operationId: 'fake-video-url', videoUrl: 'https://example.com/fake.mp4' })).status, 400);
    assert.equal((await post({ operationId: 'mixed-story-media', videoUrl: asset.data.videoUrl, imageUrl: 'https://example.com/a.png' })).status, 400);
    const first = await post({ operationId: 'video-story-one', videoUrl: asset.data.videoUrl, videoDuration: 9999 });
    assert.equal(first.status, 201); assert.equal(first.data.awarded, 100);
    assert.equal((await Story.findById(first.data.id)).videoDuration, 12.5, 'duration is server trusted');
    assert.equal((await post({ operationId: 'video-story-one', videoUrl: asset.data.videoUrl })).data.id, first.data.id);
    assert.equal((await post({ operationId: 'video-story-two', videoUrl: asset.data.videoUrl })).data.awarded, 0);
    const feed = await (await fetch(base, { headers: auth(0) })).json();
    assert.equal(feed.stories[0].videoUrl, asset.data.videoUrl); assert.equal(feed.stories[0].videoDuration, 12.5);
    await StoryVideo.updateMany({}, { $set: { expiresAt: new Date(0) } });
    assert.equal((await post({ operationId: 'expired-upload', videoUrl: asset.data.videoUrl })).status, 400);
    assert.equal((await upload(Buffer.alloc(25 * 1024 * 1024 + 1))).status, 413);
  } finally {
    videoUpload.uploadStoryVideo = original;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
