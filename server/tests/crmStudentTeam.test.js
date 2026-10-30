const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('CRM assignment is shared by student web/mobile team and scoped messaging', async () => {
  process.env.JWT_SECRET = 'synthetic-crm-team-only';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Team = require('../src/models/StudentSupportTeam'); await Team.init();
    const make = (name, role, permissions = []) => User.create({ name, email: `${name}@example.test`, role, permissions, isActive: true });
    const admin = await make('admin', 'admin'), student = await make('student', 'student'), other = await make('other', 'student');
    const one = await make('first', 'employee', ['support']), two = await make('second', 'employee', ['support']);
    const unauthorized = await make('no-support', 'employee', ['students']);
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const request = (route, user, method = 'GET', body) => fetch(`http://127.0.0.1:${server.address().port}/api${route}`, { method,
      headers: { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}`, 'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
    const route = `/crm/students/${student.id}/support-team`;
    assert.equal((await request(route, one, 'PUT', { memberIds: [one.id] })).status, 403);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [unauthorized.id] })).status, 400);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [one.id, one.id] })).status, 400);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [one.id] })).status, 200);
    let result = await request('/students/support-team', student);
    assert.equal(result.headers.get('cache-control'), 'no-store');
    assert.deepEqual((await result.json()).map(member => member._id), [one.id]);
    assert.deepEqual(await (await request('/students/support-team', other)).json(), []);
    const team = await (await request(route, admin)).json();
    assert.equal(team.canEdit, true); assert.equal(team.members[0]._id, one.id); assert.equal(team.members[0].email, undefined);
    assert.deepEqual((await (await request('/mobile-workspace/contacts?supportTeam=true', student)).json()).map(row => row._id), [one.id]);
    assert.equal((await request(`/mobile-workspace/contacts/${one.id}`, student)).status, 200);
    assert.equal((await request(`/mobile-workspace/contacts/${two.id}`, student)).status, 403);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [two.id] })).status, 200);
    assert.equal((await request(`/mobile-workspace/contacts/${one.id}`, student)).status, 403);
    assert.equal((await request(`/mobile-workspace/contacts/${two.id}`, student)).status, 200);
    await User.updateOne({ _id: two._id }, { isActive: false });
    assert.deepEqual(await (await request('/students/support-team', student)).json(), []);
    await User.updateOne({ _id: two._id }, { isActive: true });
    assert.equal((await request(route, admin, 'PUT', { memberIds: [one.id] })).status, 200);
    const advisorRoute = `/crm/students/${student.id}/advisor`;
    assert.equal((await request(advisorRoute, one, 'PUT', { advisorId: two.id })).status, 403);
    assert.equal((await request(advisorRoute, admin, 'PUT', { advisorId: unauthorized.id })).status, 400);
    assert.equal((await request(advisorRoute, admin, 'PUT', { advisorId: two.id })).status, 200);
    assert.equal((await request(advisorRoute, admin, 'PUT', { advisorId: two.id })).status, 200);
    assert.deepEqual((await (await request('/students/support-team', student)).json()).map(row => row._id).sort(), [one.id, two.id].sort());
    assert.equal((await request(`/mobile-workspace/contacts/${two.id}`, student)).status, 200);
    assert.equal((await request(advisorRoute, admin, 'PUT', { advisorId: null })).status, 200);
    assert.deepEqual((await (await request('/students/support-team', student)).json()).map(row => row._id), [one.id]);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
