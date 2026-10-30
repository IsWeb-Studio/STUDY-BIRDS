const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('community supports optional photos, true admin filtering and unique replaceable reactions', async () => {
  process.env.JWT_SECRET = 'community-media-isolated-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Post = require('../src/models/CommunityPost');
    const Reaction = require('../src/models/CommunityReaction');
    const Suspension = require('../src/models/CommunitySuspension');
    require('../src/models/Country'); require('../src/models/University'); require('../src/models/StudyField');
    const users = await User.create(['student', 'student', 'admin', 'parent'].map((role, index) => ({
      name: `Person ${index}`, email: `post${index}@example.test`, role, isActive: true,
    })));
    await Promise.all([Post.init(), Reaction.init()]);
    const images = require('../src/utils/chatImages');
    const storage = require('../src/config/cloudinary');
    let uploads = 0, reads = 0, removed = 0;
    images.uploadChatImage = async () => ({ publicId: `private-community-${++uploads}`, format: 'jpg' });
    images.readChatImage = async () => { reads++; return Buffer.from([255, 216, 255, 217]); };
    storage.ensureCloudinaryConfigured = () => {};
    storage.cloudinary.uploader.destroy = async (_, options) => { assert.equal(options.type, 'authenticated'); removed++; return { result: 'ok' }; };
    const app = require('../src/app');
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, route, user = 0, body) {
      const form = body instanceof FormData;
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/community${route}`, {
        method, headers: { ...(form ? {} : { 'Content-Type': 'application/json' }),
          ...(user == null ? {} : { Authorization: `Bearer ${jwt.sign({ userId: users[user]._id }, process.env.JWT_SECRET)}` }) },
        ...(body ? { body: form ? body : JSON.stringify(body) } : {}),
      });
      return { status: response.status, data: response.headers.get('content-type')?.includes('application/json') ? await response.json() : await response.arrayBuffer() };
    }
    const capability = await fetch(`http://127.0.0.1:${server.address().port}/api/mobile/capabilities`).then(r => r.json());
    assert.equal(capability.communityPosts.version, 2); assert.equal(capability.communityPosts.images, true);
    const student = await call('POST', '/posts', 0, { body: 'A text-only student post', isAdminPost: true, operationId: 'plain-post-123' });
    assert.equal(student.status, 201); assert.equal(student.data.isAdminPost, false); assert.equal(student.data.imagePath, null);
    assert.equal(student.data.author.name, 'Person 0'); assert.equal(student.data.author.role, 'student');
    assert.equal((await call('POST', '/posts', 0, { body: 'A text-only student post', operationId: 'plain-post-123' })).data._id, student.data._id);
    const official = await call('POST', '/posts', 2, { body: 'Official update' });
    assert.equal(official.status, 201); assert.equal(official.data.isAdminPost, true);
    assert.equal((await call('POST', '/posts', 3, { body: 'Parent post' })).status, 201);
    const adminFeed = await call('GET', '/posts?admin=1');
    assert.deepEqual(adminFeed.data.map(post => post._id), [official.data._id]);
    assert.equal((await call('GET', '/posts?mine=1&admin=1')).status, 400);
    const postId = student.data._id;
    assert.equal((await call('PATCH', `/posts/${postId}`, 1, { body: 'Not mine' })).status, 404);
    assert.equal((await call('PATCH', `/posts/${postId}`, 0, { title: '', body: 'Updated text-only post' })).status, 200);
    const route = `/posts/${postId}/reaction`;
    assert.equal((await call('PUT', route, null, { reaction: 'love' })).status, 401);
    assert.equal((await call('PUT', route, 1, { reaction: 'invalid' })).status, 400);
    await Promise.all(Array.from({ length: 4 }, () => call('PUT', route, 1, { reaction: 'love' })));
    assert.equal(await Reaction.countDocuments({ post: postId, user: users[1]._id }), 1);
    const changed = await call('PUT', route, 1, { reaction: 'laugh' });
    assert.equal(changed.data.reactionTotal, 1); assert.deepEqual(changed.data.reactionCounts, { laugh: 1 });
    await call('PUT', route, 2, { reaction: 'trophy' });
    const thread = await call('GET', `/posts/${postId}`, 1);
    assert.equal(thread.data.post.myReaction, 'laugh'); assert.equal(thread.data.post.reactionTotal, 2);
    assert.equal((await call('DELETE', route, 1)).data.reactionTotal, 1);
    assert.equal((await call('DELETE', route, 1)).data.reactionTotal, 1);
    const form = () => {
      const data = new FormData(); data.set('body', 'Optional photo'); data.set('operationId', 'image-post-123');
      data.set('file', new Blob([new Uint8Array([255, 216, 255, 217])], { type: 'image/jpeg' }), 'photo.jpg'); return data;
    };
    const photo = await call('POST', '/posts/image', 0, form());
    assert.equal(photo.status, 201); assert.ok(photo.data.imagePath); assert.equal(photo.data.image, undefined);
    assert.equal((await call('POST', '/posts/image', 0, form())).data._id, photo.data._id); assert.equal(uploads, 1);
    assert.equal((await call('GET', `/posts/${photo.data._id}/image`, null)).status, 401); assert.equal(reads, 0);
    assert.equal((await call('GET', `/posts/${photo.data._id}/image`, 1)).status, 200);
    await Post.updateOne({ _id: photo.data._id }, { $set: { status: 'hidden' } });
    assert.equal((await call('GET', `/posts/${photo.data._id}/image`, 1)).status, 404);
    assert.equal((await call('GET', `/posts/${photo.data._id}/image`, 0)).status, 200);
    assert.equal((await call('DELETE', `/posts/${photo.data._id}`, 1)).status, 404);
    assert.equal((await call('DELETE', `/posts/${photo.data._id}`, 0)).status, 200); assert.equal(removed, 1);
    await Suspension.create({ user: users[1]._id, reason: 'Test restriction', suspendedBy: users[2]._id });
    assert.equal((await call('PUT', route, 1, { reaction: 'like' })).status, 403);
    await Post.updateOne({ _id: postId }, { $set: { status: 'hidden' } });
    assert.equal((await call('PUT', route, 0, { reaction: 'love' })).status, 404);
    assert.equal((await call('DELETE', `/posts/${postId}`, 0)).status, 200);
    assert.equal(await Reaction.countDocuments({ post: postId }), 0);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
