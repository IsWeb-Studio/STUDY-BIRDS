const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('admin adverts are isolated by placement, active state and refreshed after mutations', async () => {
  process.env.JWT_SECRET = 'banner-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, ip: '127.0.0.1' } });
  const uploader = require('../src/utils/uploadToCloudinary');
  const original = uploader.uploadFileToCloudinary;
  uploader.uploadFileToCloudinary = async () => ({ url: 'https://example.test/banner.jpg', publicId: 'banner' });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Banner = require('../src/models/Banner');
    const [admin, student] = await User.create(['admin', 'student'].map(role => ({ name: role, email: `${role}@banner.test`, role })));
    const c = require('../src/controllers/bannerController');
    const { protect, authorize } = require('../src/middleware/authMiddleware');
    const { cacheRoute, clearResponseCache } = require('../src/utils/responseCache');
    clearResponseCache();
    const app = express(); app.use(express.json());
    app.get('/banners', cacheRoute(), c.getBannersPublic);
    app.use('/admin', protect, authorize('admin'));
    app.post('/admin/banners', c.createBanner); app.put('/admin/banners/:id', c.updateBanner);
    app.delete('/admin/banners/:id', c.deleteBanner);
    app.post('/admin/upload', (req, res, next) => { req.file = {}; next(); }, c.uploadBannerImage);
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}`;
    const call = async (route, method = 'GET', body, user = admin) => {
      const r = await fetch(base + route, { method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` }, body: body === undefined ? undefined : JSON.stringify(body) });
      return { status: r.status, data: await r.json() };
    };
    for (const placement of ['home', 'community', 'both']) assert.equal((await call('/admin/banners', 'POST', { title: placement, placement })).status, 201);
    await Banner.collection.insertOne({ title: 'legacy', active: true, order: 0 });
    await Banner.create({ title: 'hidden', placement: 'community', active: false });
    assert.deepEqual((await call('/banners')).data.map(b => b.title).sort(), ['both', 'home', 'legacy']);
    const community = (await call('/banners?placement=community')).data;
    assert.deepEqual(community.map(b => b.title).sort(), ['both', 'community']);
    const ad = community.find(b => b.title === 'community');
    assert.equal((await call(`/admin/banners/${ad._id}`, 'PUT', { active: false })).status, 200);
    assert.deepEqual((await call('/banners?placement=community')).data.map(b => b.title), ['both']);
    assert.equal((await Banner.findById(ad._id)).title, 'community', 'partial edits preserve content');
    assert.equal((await call('/admin/banners', 'POST', { title: 'bad', placement: 'invalid' })).status, 400);
    assert.equal((await call('/banners?placement=invalid')).status, 400);
    assert.equal((await call('/admin/banners', 'POST', { title: 'student ad', placement: 'community' }, student)).status, 403);
    assert.equal((await call('/admin/upload', 'POST', {})).data.url, 'https://example.test/banner.jpg');
    const both = community.find(b => b.title === 'both');
    assert.equal((await call(`/admin/banners/${both._id}`, 'DELETE')).status, 200);
    assert.deepEqual((await call('/banners?placement=community')).data, []);
  } finally {
    uploader.uploadFileToCloudinary = original;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
