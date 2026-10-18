const { test } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('student teams are managed on the web and scope ticket delivery, access and replies', async () => {
  process.env.JWT_SECRET = 'support-team-test-only';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Ticket = require('../src/models/SupportTicket');
    const Notification = require('../src/models/Notification');
    const Team = require('../src/models/StudentSupportTeam'); await Team.init();
    const create = (name, role, permissions = [], isActive = true) => User.create({ name, email: `${name}@example.test`, role, permissions, isActive });
    const admin = await create('admin', 'admin');
    const student = await create('student', 'student');
    const other = await create('other', 'student');
    const one = await create('one', 'employee', ['support']);
    const two = await create('two', 'employee', ['support']);
    const outsider = await create('outsider', 'employee', ['support']);
    const inactive = await create('inactive', 'employee', ['support'], false);
    const app = require('../src/app');
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    const request = (route, user, method = 'GET', body) => fetch(base + route, { method,
      headers: { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}`, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}) });
    const route = `/admin/students/${student._id}/support-team`;
    assert.equal((await request(route, outsider, 'PUT', { memberIds: [one.id] })).status, 403);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [student.id] })).status, 400);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [inactive.id] })).status, 400);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [one.id, two.id] })).status, 200);
    const members = await (await request('/students/support-team', student)).json();
    assert.deepEqual(members.map(m => m.name).sort(), ['one', 'two']);
    assert.equal(members[0].email, undefined);
    assert.deepEqual(await (await request('/students/support-team', other)).json(), []);
    const created = await request('/students/support-tickets', student, 'POST', { subject: 'App problem', message: 'Something failed', category: 'technical-issue' });
    assert.equal(created.status, 201); const ticket = await created.json();
    const notices = await Notification.find({ link: `/admin/support-tickets#ticket-${ticket._id}` }).lean();
    assert.deepEqual(notices.map(n => String(n.user)).sort(), [one.id, two.id].sort());
    const list = async user => (await request('/admin/support-tickets', user)).json();
    assert.equal((await list(one)).length, 1); assert.equal((await list(outsider)).length, 0);
    assert.equal((await request(`/admin/support-tickets/${ticket._id}`, outsider)).status, 404);
    assert.equal((await request(`/admin/support-tickets/${ticket._id}/reply`, outsider, 'PATCH', { message: 'No' })).status, 404);
    assert.equal((await request(`/admin/support-tickets/${ticket._id}/reply`, two, 'PATCH', { message: 'We can help' })).status, 200);
    const mine = await (await request('/students/support-tickets', student)).json();
    assert.equal(mine[0].replies.at(-1).message, 'We can help');
    assert.equal(mine[0].replies.at(-1).displayName, 'two');
    assert.deepEqual(await (await request('/students/support-tickets', other)).json(), []);
    assert.equal((await request(route, admin, 'PUT', { memberIds: [outsider.id] })).status, 200);
    assert.equal((await list(one)).length, 0); assert.equal((await list(outsider)).length, 1);
    assert.equal((await request(`/admin/support-tickets/${ticket._id}/reply`, one, 'PATCH', { message: 'Old member' })).status, 404);
    await User.updateOne({ _id: outsider._id }, { isActive: false });
    assert.deepEqual(await (await request('/students/support-team', student)).json(), []);
    // Keep urgent support access as before.
    await Ticket.updateOne({ _id: ticket._id }, { isEmergency: true });
    assert.equal((await list(one)).length, 1);
    assert.equal((await request(`/admin/support-tickets/${ticket._id}`, one)).status, 200);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
