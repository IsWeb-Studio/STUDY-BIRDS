const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const crypto = require('node:crypto');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('store safety: ownership verification, durable deletion, storage retry and blocking', async () => {
  process.env.JWT_SECRET = 'isolated-store-safety-test-only';
  let mongo, server;
  const { cloudinary } = require('../src/config/cloudinary');
  const oldDestroy = cloudinary.uploader.destroy;
  const mailer = require('../src/utils/mailer');
  const oldMailerConfigured = mailer.isMailerConfigured;
  const oldSendEmail = mailer.sendContactEmail;
  try {
    mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1', launchTimeout: 60000 } });
    await mongoose.connect(mongo.getUri());
    const app = require('../src/app');
    server = app.listen(0, '127.0.0.1');
    await new Promise(resolve => server.once('listening', resolve));
    const base = `http://127.0.0.1:${server.address().port}/api`;
    const User = require('../src/models/User');
    const Post = require('../src/models/CommunityPost');
    const Comment = require('../src/models/CommunityComment');
    const Job = require('../src/models/AccountDeletionJob');
    const { EmailCode, Session, Message } = require('../src/models/MobileWorkspace');
    const Document = require('../src/models/Document');
    const Invoice = require('../src/models/Invoice');
    const { processDeletion } = require('../src/utils/accountDeletion');
    const [alice, bob, third] = await User.create([
      { name: 'Alice', email: 'alice@example.test', role: 'student', authProvider: 'google' },
      { name: 'Bob', email: 'bob@example.test', role: 'student', password: 'StrongPass!123' },
      { name: 'Third', email: 'third@example.test', role: 'student', password: 'StrongPass!123' },
    ]);
    const call = async (route, { user, method = 'GET', body } = {}) => {
      const response = await fetch(base + route, { method, headers: { 'Content-Type': 'application/json',
        ...(user ? { Authorization: `Bearer ${jwt.sign({ userId: String(user._id) }, process.env.JWT_SECRET)}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: response.status, data: await response.json() };
    };
    const bobPost = await Post.create({ author: bob._id, title: 'Bob post', body: 'Hello' });
    const otherPost = await Post.create({ author: third._id, title: 'Third post', body: 'Unrelated' });
    assert.equal((await call(`/safety/blocks/${bob._id}`, { user: alice, method: 'PUT' })).status, 200);
    assert.equal((await call('/safety/blocks', { user: alice })).data.length, 1);
    assert.equal((await call(`/community/posts/${bobPost._id}`, { user: alice })).status, 404);
    assert.equal((await call('/mobile-workspace/messages', { user: bob, method: 'POST', body: { recipient: String(alice._id), body: 'blocked' } })).status, 403);
    assert.equal((await call(`/safety/blocks/${alice._id}`, { user: alice, method: 'PUT' })).status, 400);
    assert.equal((await call(`/safety/blocks/${bob._id}`, { user: alice, method: 'DELETE' })).status, 200);
    assert.equal((await call(`/community/posts/${bobPost._id}`, { user: alice })).status, 200);
    assert.equal((await call('/safety/reports', { user: alice, method: 'POST', body: { reason: 'Harmful advice', content: 'Synthetic AI answer' } })).status, 201);
    assert.equal(await mongoose.model('SupportTicket').countDocuments({ user: alice._id, escalated: true }), 1);

    // Passwordless deletion cannot be triggered by merely stealing a session.
    assert.equal((await call('/auth/account', { user: alice, method: 'DELETE', body: {} })).status, 400);
    assert.equal(await Job.countDocuments(), 0);
    assert.equal((await call('/auth/account', { user: bob, method: 'DELETE', body: { password: 'wrong' } })).status, 401);
    assert.equal((await call('/auth/account-deletion/request', { method: 'POST', body: { email: 'absent@example.test' } })).status, 200);

    const ownPost = await Post.create({ author: alice._id, title: 'Own content', body: 'Delete me', hasImage: true,
      image: { publicId: 'private-community-photo', format: 'jpg', resourceType: 'image', deliveryType: 'authenticated' } });
    const Reaction = require('../src/models/CommunityReaction');
    await Reaction.create({ post: ownPost._id, user: bob._id, reaction: 'love' });
    await Comment.create({ post: ownPost._id, author: bob._id, body: 'Child of deleted post' });
    await Comment.create({ post: otherPost._id, author: alice._id, body: 'Own comment' });
    await Document.create({ student: alice._id, type: 'passport', fileName: 'passport.pdf', filePath: '/private',
      storage: { publicId: 'synthetic/private.pdf', resourceType: 'raw', deliveryType: 'authenticated' } });
    await Session.create({ user: alice._id, digest: 'synthetic-refresh-token' });
    await Message.create({ sender: alice._id, recipient: bob._id, body: 'Private message',
      audio: { publicId: 'private-voice-message', resourceType: 'video', deliveryType: 'authenticated', format: 'm4a', duration: 2 } });
    const sharedTicket = await mongoose.model('SupportTicket').create({ user: bob._id, subject: 'Shared ticket', message: 'Help', replies: [
      { user: alice._id, fromRole: 'student', message: 'Voice', audioStorage: { publicId: 'private-voice-reply', resourceType: 'video', deliveryType: 'authenticated' } },
      { user: bob._id, fromRole: 'student', message: 'Keep', audioStorage: { publicId: 'keep-other-voice', resourceType: 'video', deliveryType: 'authenticated' } },
    ] });
    const invoice = await Invoice.create({ student: alice._id, invoiceNumber: 'isolated-test', description: 'Private name', amount: 123 });
    const code = '123456';
    await EmailCode.create({ user: alice._id, email: alice.email, purpose: 'delete-account',
      digest: crypto.createHmac('sha256', process.env.JWT_SECRET).update(`${alice._id}:delete-account:${code}`).digest('hex'),
      expiresAt: new Date(Date.now() + 600000) });
    assert.equal((await call('/auth/account-deletion/confirm', { method: 'POST', body: { email: alice.email, code: '000000' } })).status, 400);
    assert.equal((await call('/auth/account-deletion/confirm', { method: 'POST', body: { email: alice.email, code } })).status, 202);
    assert.equal((await User.findById(alice._id)).isActive, false);
    assert.equal((await call('/auth/me', { user: alice })).status, 403);
    const job = await Job.findOne({ user: alice._id });
    cloudinary.uploader.destroy = async () => { throw new Error('Synthetic storage outage'); };
    await assert.rejects(() => processDeletion(job));
    assert.ok(await Job.exists({ _id: job._id }));
    assert.ok((await Job.findById(job._id)).snapshot.assets.length);
    const deletedAssets = [];
    cloudinary.uploader.destroy = async (id, options) => { deletedAssets.push({ id, options }); return { result: 'ok' }; };
    mailer.isMailerConfigured = () => true;
    mailer.sendContactEmail = async () => { throw new Error('Synthetic email outage'); };
    await assert.rejects(() => processDeletion(Job.hydrate(job.toObject())));
    assert.equal((await Job.findById(job._id)).state, 'complete');
    const replacement = await User.create({ name: 'Replacement', email: alice.email, role: 'student' });
    const EmailDelivery = require('../src/models/EmailDelivery');
    await EmailDelivery.create({ key: 'replacement-message', to: alice.email, subject: 'New account', text: 'Keep this' });
    mailer.sendContactEmail = async () => {};
    await processDeletion(await Job.findById(job._id));
    assert.ok(await User.exists({ _id: replacement._id }));
    assert.equal(await EmailDelivery.countDocuments({ key: 'replacement-message' }), 1);
    assert.equal(await User.exists({ _id: alice._id }), null);
    assert.equal(await Document.countDocuments({ student: alice._id }), 0);
    assert.equal(await Session.countDocuments({ user: alice._id }), 0);
    assert.equal(await Message.countDocuments({ sender: alice._id }), 0);
    for (const id of ['private-voice-message', 'private-voice-reply']) {
      const removed = deletedAssets.find(asset => asset.id === id);
      assert.ok(removed, `deleted ${id}`);
      assert.equal(removed.options.resource_type, 'video');
      assert.equal(removed.options.type, 'authenticated');
    }
    assert.ok(!deletedAssets.some(asset => asset.id === 'keep-other-voice'));
    const communityImage = deletedAssets.find(asset => asset.id === 'private-community-photo');
    assert.ok(communityImage);
    assert.equal(communityImage.options.resource_type, 'image');
    assert.equal(communityImage.options.type, 'authenticated');
    assert.equal(await Reaction.countDocuments({ post: ownPost._id }), 0);
    assert.equal((await mongoose.model('SupportTicket').findById(sharedTicket._id)).replies.length, 1);
    assert.equal(await Comment.countDocuments({ post: ownPost._id }), 0);
    assert.equal(await Comment.countDocuments({ author: alice._id }), 0);
    assert.ok(await Post.exists({ _id: otherPost._id }));
    const retained = await Invoice.findById(invoice._id).lean();
    assert.equal(retained.amount, 123);
    assert.equal(retained.student, undefined);
    assert.equal(retained.description, 'Retained accounting record');
    assert.equal(await Job.countDocuments(), 0);
  } finally {
    cloudinary.uploader.destroy = oldDestroy;
    mailer.isMailerConfigured = oldMailerConfigured;
    mailer.sendContactEmail = oldSendEmail;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  }
});
