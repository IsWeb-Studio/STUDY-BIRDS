process.env.CLOUDINARY_CLOUD_NAME = 'test';
process.env.CLOUDINARY_API_KEY = 'synthetic-key';
process.env.CLOUDINARY_API_SECRET = 'synthetic-secret';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('mobile buttons reach actual routes and preserve account ownership', async () => {
  process.env.CLOUDINARY_CLOUD_NAME = 'test';
  process.env.JWT_SECRET = 'isolated-button-contract-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const uploads = require('../src/utils/uploadToCloudinary');
    uploads.uploadFileToCloudinary = async () => ({ url: 'https://res.cloudinary.com/test/image/upload/photo.png' });
    const app = require('../src/app');
    const User = require('../src/models/User');
    const Notification = require('../src/models/Notification');
    const { Story, StoryInteraction } = require('../src/models/Stories');
    const users = await User.create(['student', 'parent', 'admin'].map((role, i) => ({
      name: `User ${i}`, email: `button${i}@example.test`, role, isActive: true,
    })));
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, who = 0, body) {
      const form = body instanceof FormData;
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${route}`, {
        method, headers: { ...(form ? {} : { 'Content-Type': 'application/json' }),
          ...(who == null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[who]._id }, process.env.JWT_SECRET)}` }) },
        ...(body ? { body: form ? body : JSON.stringify(body) } : {}),
      });
      return { status: response.status, data: await response.json() };
    }
    assert.equal((await call('PATCH', '/auth/me/profile', null, { name: 'No' })).status, 401);
    assert.equal((await call('PATCH', '/auth/me/profile', 1, { name: 'New name', role: 'admin' })).status, 400);
    const renamed = await call('PATCH', '/auth/me/profile', 1, { name: 'New name' });
    assert.equal(renamed.status, 200); assert.equal(renamed.data.user.name, 'New name');
    assert.equal(renamed.data.user.password, undefined); assert.equal(renamed.data.user.role, 'parent');
    const form = new FormData();
    form.set('file', new Blob([Buffer.from('89504e470d0a1a0a00000000', 'hex')], { type: 'image/png' }), 'avatar.png');
    const avatar = await call('POST', '/auth/avatar', 1, form);
    assert.equal(avatar.status, 200); assert.match(avatar.data.user.avatar, /^https:/);
    const notes = await Notification.insertMany(users.slice(0, 2).map(user => ({ user: user._id, title: 'Notice', message: 'Test', link: '/student/applications' })));
    const own = await call('GET', '/content/notifications');
    assert.equal(own.data[0].link, '/student/applications');
    assert.equal((await call('PATCH', `/content/notifications/${notes[1]._id}/read`)).status, 404);
    assert.equal((await call('PATCH', `/content/notifications/${notes[0]._id}/read`)).status, 200);
    assert.equal((await call('PATCH', '/content/notifications/read-all', 1)).status, 200);
    assert.equal((await Notification.findById(notes[1]._id)).isRead, true);
    assert.equal((await call('GET', '/accommodation/listings')).status, 200);
    assert.equal((await call('GET', '/accommodation/bookings/mine')).status, 200);
    assert.equal((await call('POST', '/accommodation/bookings', 0, { listingId: 'invalid' })).status, 400);
    assert.equal((await call('GET', '/admin/community-overview')).status, 403);
    assert.equal((await call('GET', '/admin/community-overview', 2)).status, 200);
    const teamPath = `/admin/students/${users[0]._id}/support-team`;
    assert.equal((await call('GET', teamPath, 2)).status, 200);
    assert.equal((await call('PUT', teamPath, 2, { memberIds: [String(users[2]._id)] })).status, 200);
    const team = await call('GET', teamPath, 2);
    assert.deepEqual(team.data.memberIds, [String(users[2]._id)]);
    assert.equal(team.data.teamMembers.length, 1);
    assert.equal((await call('PUT', teamPath, 1, { memberIds: [] })).status, 403);
    const story = await Story.create({ author: users[0]._id, operationId: 'story-button-test', text: 'Story', expiresAt: new Date(Date.now() + 60000) });
    await StoryInteraction.create({ story: story._id, user: users[1]._id, seenAt: new Date() });
    assert.equal((await call('GET', `/stories/${story._id}/viewers`, 1)).status, 404);
    const viewers = await call('GET', `/stories/${story._id}/viewers`);
    assert.equal(viewers.status, 200); assert.equal(viewers.data.viewers[0].id, String(users[1]._id));
    assert.equal((await call('DELETE', `/stories/${story._id}`, 1)).status, 404);
    assert.equal((await call('DELETE', `/stories/${story._id}`)).status, 200);
    assert.equal((await call('DELETE', `/stories/${story._id}`)).status, 200);
    assert.equal((await call('GET', `/stories/${story._id}/viewers`)).status, 404);
    assert.equal(await StoryInteraction.countDocuments({ story: story._id }), 0);
    const tombstone = await Story.findById(story._id);
    assert.ok(tombstone.deletedAt); assert.equal(tombstone.text, '');
    const storage = require('../src/config/cloudinary');
    storage.ensureCloudinaryConfigured = () => {};
    let failStorage = true, destroyed = 0;
    storage.cloudinary.uploader.destroy = async () => {
      if (failStorage) throw new Error('mock provider unavailable');
      destroyed++; return { result: 'ok' };
    };
    const imageUrl = `https://res.cloudinary.com/test/image/upload/v1/story-images/${users[0]._id}/photo.jpg`;
    const photo = await Story.create({ author: users[0]._id, operationId: 'photo-button-test', imageUrl, expiresAt: new Date(Date.now() + 60000) });
    assert.equal((await call('DELETE', `/stories/${photo._id}`)).status, 200);
    const maintenance = require('../src/utils/mediaMaintenance');
    await maintenance.runMaintenance();
    const Job = require('../src/models/MaintenanceJob');
    assert.equal(await Job.countDocuments({kind:'media', attempts:1}), 1);
    await Job.updateMany({kind:'media'}, {$set:{dueAt:new Date()}});
    failStorage = false;
    assert.equal((await call('DELETE', `/stories/${photo._id}`)).status, 200);
    await maintenance.runMaintenance();
    assert.equal(destroyed, 1); assert.equal((await Story.findById(photo._id)).imageUrl, '');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
