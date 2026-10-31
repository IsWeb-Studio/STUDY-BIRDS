const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('photo soundtrack enforces upload ownership, expiry, duration and cleanup', async () => {
  process.env.JWT_SECRET = 'story-audio-test';
  process.env.CLOUDINARY_CLOUD_NAME = 'audio-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  const helper = require('../src/utils/storyAudioUpload');
  const original = helper.uploadStoryAudio;
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Audio = require('../src/models/StoryAudio');
    const { Story, StoryStats } = require('../src/models/Stories');
    await Promise.all([User.init(), Audio.init(), Story.init(), StoryStats.init()]);
    const users = await User.create([0, 1].map(i => ({ name: `Audio ${i}`, email: `audio${i}@example.test`, role: 'student' })));
    helper.uploadStoryAudio = async (file, owner) => {
      helper.validateAudio(file);
      return { publicId: `story-audio/${owner}/clip`, audioUrl: `https://res.cloudinary.com/audio-test/video/upload/story-audio/${owner}/clip.mp3`, duration: 12 };
    };
    const app = express(); app.use(express.json()); app.use('/stories', require('../src/routes/storyRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/stories`;
    const auth = i => ({ Authorization: `Bearer ${jwt.sign({ userId: users[i]._id }, process.env.JWT_SECRET)}` });
    const request = async (body, i = 0) => {
      const r = await fetch(base, { method: 'POST', headers: { ...auth(i), 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      return { status: r.status, data: await r.json() };
    };
    const upload = async bytes => {
      const form = new FormData(); form.append('file', new Blob([bytes], { type: 'audio/mpeg' }), 'clip.mp3');
      const r = await fetch(base + '/audio', { method: 'POST', headers: auth(0), body: form });
      return { status: r.status, data: await r.json() };
    };
    assert.equal((await upload(Buffer.from('not audio at all'))).status, 415);
    const asset = await upload(Buffer.from('ID3abcdefghijklmno'));
    assert.equal(asset.status, 200);
    const photo = i => `https://res.cloudinary.com/audio-test/image/upload/story-images/${users[i]._id}/photo.jpg`;
    const body = { operationId: 'audio-story-one', imageUrl: photo(0), audioUrl: asset.data.audioUrl };
    assert.equal((await request({ ...body, imageUrl: photo(1) }, 1)).status, 400);
    assert.equal((await request({ ...body, audioUrl: 'https://example.test/audio.mp3' })).status, 400);
    assert.equal((await request({ ...body, audioDuration: 999 })).status, 400);
    assert.equal((await request({ ...body, imageUrl: '' })).status, 400);
    const posted = await request(body);
    assert.equal(posted.status, 201, JSON.stringify(posted));
    assert.equal(posted.data.awarded, 100);
    assert.equal((await request(body)).data.id, posted.data.id);
    const feed = await (await fetch(base, { headers: auth(0) })).json();
    assert.equal(feed.stories[0].audioUrl, asset.data.audioUrl);
    assert.equal(feed.stories[0].audioDuration, 12);
    await Audio.updateMany({}, { $set: { expiresAt: new Date(0) } });
    assert.equal((await request({ ...body, operationId: 'expired-audio-story' })).status, 400);
    const removed = await fetch(base + '/' + posted.data.id, { method: 'DELETE', headers: auth(0) });
    assert.equal(removed.status, 200);
    assert.equal((await Story.findById(posted.data.id)).audioUrl, '');
    const Job = require('../src/models/MaintenanceJob');
    assert.ok(await Job.exists({ publicId: `story-audio/${users[0]._id}/clip`, dueAt: { $lte: new Date() } }));
  } finally {
    helper.uploadStoryAudio = original;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
