const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
const { studentNextAction } = require('../src/utils/studentNextAction');
const { studentJourneys } = require('../src/utils/studentJourney');

test('post-admission workflow is scoped, staff-controlled, versioned and reflected in the student journey', async () => {
  process.env.JWT_SECRET = 'post-admission-isolated-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User'); const Application = require('../src/models/Application');
    const student = await User.create({ name: 'Student', email: 'student@example.test' });
    const other = await User.create({ name: 'Other', email: 'other@example.test' });
    const staff = await User.create({ name: 'Staff', email: 'staff@example.test', role: 'employee', permissions: ['applications'] });
    const finance = await User.create({ name: 'Finance', email: 'finance@example.test', role: 'employee', permissions: ['student-financials'] });
    const app = await Application.create({ student: student._id, program: new mongoose.Types.ObjectId(), university: new mongoose.Types.ObjectId(), detailedStatus: 'final-admission', requiredDocumentTypes: [] });
    const unrelated = await Application.create({ student: other._id, program: new mongoose.Types.ObjectId(), university: new mongoose.Types.ObjectId(), detailedStatus: 'final-admission', requiredDocumentTypes: [] });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const route = `/applications/${app._id}/post-admission`;
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }
    await call('GET', route, null, null, 401);
    await call('GET', route, other, null, 404);
    await call('GET', route, finance, null, 403);
    const initial = await call('GET', route, student);
    assert.equal(initial.stages.length, 6);
    assert.ok(initial.stages.every(s => s.status === 'not-started'));
    const body = { stage: 'visa', status: 'action-required', note: 'جهز موعد السفارة وتواصل مع مسؤولك', dueAt: '2020-01-01T00:00:00Z', version: 0 };
    await call('PATCH', route, student, body, 403);
    await call('PATCH', route, finance, body, 403);
    for (const invalid of [{ stage: '__proto__' }, { status: 'invented' }, { note: ' ' }, { dueAt: 'invalid' }, { status: 'completed' }, { reference: 123 }, { version: -1 }]) {
      await call('PATCH', route, staff, { ...body, ...invalid }, 400);
    }
    const changed = await call('PATCH', route, staff, body);
    assert.equal(changed.version, 1); assert.equal(changed.stages[0].status, 'overdue');
    await call('PATCH', route, staff, body, 409);
    let stored = await Application.findById(app._id).lean();
    assert.equal(stored.detailedStatus, 'final-admission');
    assert.equal(stored.postAdmissionHistory.length, 1);
    assert.equal(String(stored.postAdmissionHistory[0].changedBy), String(staff._id));
    const overview = await call('GET', '/students/overview', student);
    assert.equal(overview.nextAction.code, 'post-admission-visa');
    assert.equal(overview.nextAction.destination, 'journey');
    assert.equal(overview.nextAction.waiting, false);
    assert.equal(overview.journeys[0].stages.find(s => s.key === 'visa').descriptionAr, body.note);
    const otherOverview = await call('GET', '/students/overview', other);
    assert.equal(otherOverview.journeys[0].applicationId, String(unrelated._id));
    assert.equal(otherOverview.journeys[0].stages.find(s => s.key === 'visa').status, 'not-started');
    const complete = await call('PATCH', route, staff, { ...body, status: 'completed', reference: 'VISA-VERIFIED-1', version: 1 });
    assert.equal(complete.stages[0].status, 'completed');
    const waiting = await call('PATCH', route, staff, { stage: 'housing', status: 'waiting-team', note: 'بانتظار تأكيد السكن من الفريق', version: 2 });
    assert.equal(waiting.version, 3);
    assert.equal((await call('GET', '/students/overview', student)).nextAction.waiting, true);
    // A completed admission must not automatically mark logistics complete.
    stored = await Application.findById(app._id).lean();
    assert.equal(studentJourneys({ applications: [stored] })[0].stages.find(s => s.key === 'travel').status, 'not-started');
    const urgentInvoice = { _id: 'bill', application: app._id, status: 'unpaid', dueDate: '2019-01-01' };
    assert.equal(studentNextAction({ applications: [stored], invoices: [urgentInvoice] }).code, 'payment-required');
    await Application.updateOne({ _id: app._id }, { $set: { detailedStatus: 'completed' } });
    await call('PATCH', route, staff, { ...body, version: 3 }, 409);
    const archived = (await call('GET', '/students/overview', student)).journeys[0];
    assert.equal(archived.nextAction, null);
    assert.equal(archived.stages.find(s => s.key === 'visa').reference, 'VISA-VERIFIED-1');
    await Application.updateOne({ _id: app._id }, { $set: { detailedStatus: 'under-review', status: 'under-review' } });
    await call('PATCH', route, staff, { ...body, version: 3 }, 409);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});

test('unreviewed admissions have no invented logistics stages and completion skips to the next unfinished stage', () => {
  const app = { _id: 'a', status: 'submitted', requiredDocumentTypes: [] };
  assert.equal(studentJourneys({ applications: [app] })[0].stages.length, 3);
  const accepted = { ...app, status: 'accepted', detailedStatus: 'final-admission', postAdmission: { visa: { status: 'completed', reference: 'checked' } } };
  assert.equal(studentNextAction({ applications: [accepted] }).code, 'post-admission-travel');
  assert.equal(studentJourneys({ applications: [{ ...accepted, status: 'rejected' }] })[0].nextAction, null);
});
