// Real Express routes and JWT middleware with an isolated in-memory model adapter.
// No connection to the developer's or production database is made.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { createRequire } = require('node:module');
const site = process.env.STUDY_BIRDS_SITE || 'D:/work/Study-birds';
const requireSite = createRequire(path.join(site, 'server/package.json'));
const express = requireSite('express');
const jwt = requireSite('jsonwebtoken');
const model = (name) => requireSite(`./src/models/${name}`);
const Settings = model('MobileSettings'), Content = model('MobileContent'), Request = model('MobileRequest');
const User = model('User'), Ticket = model('SupportTicket'), Document = model('Document'), Profile = model('StudentProfile');
const { defaults } = requireSite('./src/utils/mobileConfig');
let saved, content, requests, query, origin, server;
const adminId = '111111111111111111111111', studentId = '222222222222222222222222', otherId = '333333333333333333333333', itemId = '444444444444444444444444';
const result = (data) => ({ sort() { return this; }, populate() { return this; }, select() { return this; }, lean: async () => data, then: (resolve, reject) => Promise.resolve(data).then(resolve, reject) });
process.env.JWT_SECRET = 'isolated-mobile-test-secret';
const auth = (id = adminId) => `Bearer ${jwt.sign({ userId: id }, process.env.JWT_SECRET)}`;
before(() => {
  model('MobileWorkspace').Session.exists = async () => false;
  Settings.findOne = () => result(saved);
  Settings.updateOne = async () => { saved ||= { config: defaults(), revision: 0 }; };
  Settings.findOneAndUpdate = async (filter, update) => { if (saved.revision !== filter.revision) return null; saved = { config: update.$set.config, revision: saved.revision + 1 }; return saved; };
  User.findById = (id) => result({ _id: id, role: id === adminId ? 'admin' : 'student', isActive: true, save: async () => {} });
  User.exists = async (filter) => filter._id === studentId ? { _id: studentId } : null;
  Content.find = (filter) => result(content.filter((item) => !filter || item.section === filter.section && item.published === filter.published));
  Content.findOne = async (filter) => content.find((item) => item._id === filter._id && item.published && item.requestable);
  Content.create = async (input) => { const value = { _id: itemId, ...input }; content.push(value); return value; };
  Request.create = async (input) => { const value = { _id: 'request', ...input }; requests.push(value); return value; };
  Request.find = (filter) => { query = filter; return result(requests.filter((item) => !filter || item.user === filter.user)); };
  Ticket.findOneAndUpdate = async (filter) => { query = filter; return null; };
  Document.findByIdAndUpdate = async (id, update) => ({ _id: id, ...update.$set });
  Profile.findOneAndUpdate = (filter, update) => { query = { filter, update }; return result({ ...filter, ...(update.$set || update) }); };
  const app = express(); app.use(express.json()); app.use('/api/mobile', requireSite('./src/routes/mobileRoutes'));
  app.use((error, req, res, next) => res.status(res.statusCode === 200 ? 500 : res.statusCode).json({ message: error.message }));
  return new Promise((resolve) => { server = app.listen(0, '127.0.0.1', () => { origin = `http://127.0.0.1:${server.address().port}/api/mobile`; resolve(); }); });
});
after(() => new Promise((resolve) => server.close(resolve)));
beforeEach(() => { saved = null; content = []; requests = []; query = null; });
async function call(route, { method = 'GET', body, token } = {}) {
  const response = await fetch(origin + route, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: response.status, data: await response.json() };
}
test('settings are public, admin writes require authentication and role', async () => {
  assert.equal((await call('/config')).data.title, 'Study Birds');
  assert.equal((await call('/admin/settings')).status, 401);
  assert.equal((await call('/admin/settings', { token: auth(studentId) })).status, 403);
  assert.equal((await call('/admin/settings', { token: auth() })).status, 200);
});
test('expired and invalid JWTs return 401 instead of server errors', async () => {
  assert.equal((await call('/admin/settings', { token: 'Bearer invalid' })).status, 401);
  const token = jwt.sign({ userId: adminId }, process.env.JWT_SECRET, { expiresIn: -1 });
  assert.equal((await call('/admin/settings', { token: `Bearer ${token}` })).status, 401);
});
test('saved settings are read by the app and stale saves are rejected', async () => {
  const config = { ...defaults(), revision: 0, title: 'Updated mobile title' };
  const write = await call('/admin/settings', { method: 'PUT', token: auth(), body: config });
  assert.equal(write.status, 200); assert.equal(write.data.revision, 1);
  assert.equal((await call('/config')).data.title, config.title);
  assert.equal((await call('/admin/settings', { method: 'PUT', token: auth(), body: config })).status, 409);
});
test('unknown/duplicate modules and unsafe URLs cannot be published', async () => {
  const config = { ...defaults(), revision: 0 };
  config.modules[1] = config.modules[0];
  assert.equal((await call('/admin/settings', { method: 'PUT', token: auth(), body: config })).status, 400);
  const bannerConfig = { ...defaults(), revision: 0, banners: [{ title: 'Bad', imageUrl: 'javascript:alert(1)', linkUrl: '' }] };
  assert.equal((await call('/admin/settings', { method: 'PUT', token: auth(), body: bannerConfig })).status, 400);
});
test('unpublished content and disabled sections are hidden from the app', async () => {
  content = [{ _id: itemId, section: 'services', published: true }, { section: 'services', published: false }];
  assert.equal((await call('/content?section=services')).data.length, 1);
  const config = defaults(); config.modules.find((m) => m.key === 'services').enabled = false;
  saved = { config, revision: 1 };
  assert.deepEqual((await call('/content?section=services')).data, []);
  saved.config.maintenance = true;
  assert.deepEqual((await call('/content?section=services')).data, []);
});
test('content created by admin becomes available for an owned student request', async () => {
  const item = { section: 'services', title: 'Consultation', body: 'Details', published: true, requestable: true, order: 0 };
  assert.equal((await call('/admin/content', { method: 'POST', token: auth(studentId), body: item })).status, 403);
  assert.equal((await call('/admin/content', { method: 'POST', token: auth(), body: item })).status, 201);
  const request = await call('/requests', { method: 'POST', token: auth(studentId), body: { contentId: itemId, message: 'Book tomorrow', user: otherId, status: 'completed' } });
  assert.equal(request.status, 201); assert.equal(request.data.user, studentId); assert.equal(request.data.status, undefined);
  assert.equal((await call('/requests', { token: auth(otherId) })).data.length, 0);
  assert.deepEqual(query, { user: otherId });
});
test('disabled or draft services cannot receive requests', async () => {
  content = [{ _id: itemId, section: 'services', published: false, requestable: true }];
  const options = { method: 'POST', token: auth(studentId), body: { contentId: itemId, message: 'Book' } };
  assert.equal((await call('/requests', options)).status, 404);
  content[0].published = true; saved = { config: { ...defaults(), maintenance: true }, revision: 1 };
  assert.equal((await call('/requests', options)).status, 403);
});
test('ticket replies enforce ownership and reject closed tickets', async () => {
  const response = await call(`/tickets/${itemId}/reply`, { method: 'POST', token: auth(studentId), body: { message: 'Reply' } });
  assert.equal(response.status, 404);
  assert.equal(query.requesterRole, 'student');
  assert.deepEqual(query.$or, [{ user: studentId }, { agent: studentId }]);
  assert.deepEqual(query.status, { $ne: 'closed' });
});
test('only admin can review documents or set journey stage', async () => {
  const route = `/admin/students/${studentId}/stage`, body = { applicationStage: 'final-accepted' };
  assert.equal((await call(route, { method: 'PATCH', token: auth(studentId), body })).status, 403);
  assert.equal((await call(route, { method: 'PATCH', token: auth(), body })).data.applicationStage, 'final-accepted');
  assert.equal((await call(`/admin/documents/${itemId}`, { method: 'PATCH', token: auth(), body: { status: 'verified' } })).data.status, 'verified');
});
test('student profile updates cannot grant final acceptance', async () => {
  const { updateProfile } = requireSite('./src/controllers/studentController');
  let response;
  const res = { status() { return this; }, json(value) { response = value; } };
  await updateProfile({ user: { _id: studentId }, body: { phone: '12345', applicationStage: 'final-accepted' } }, res, (error) => { throw error; });
  assert.equal(query.update.applicationStage, undefined);
  assert.equal(response.phone, '12345');
});
