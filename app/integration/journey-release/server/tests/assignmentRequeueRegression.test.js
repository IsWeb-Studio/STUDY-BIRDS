const { test } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const path = require('node:path');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('manual cancellation revokes queue consent and ineligible stages cannot requeue', async () => {
  process.env.JWT_SECRET = 'requeue-regression-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User'); const Application = require('../src/models/Application');
    const staff = await User.create({ name: 'Advisor', email: 'advisor@example.test', role: 'employee', employeeRole: 'admission', permissions: ['applications'] });
    const app = await Application.create({ student: new mongoose.Types.ObjectId(), program: new mongoose.Types.ObjectId(), university: new mongoose.Types.ObjectId(), assignmentHistory: [{ advisor: null, changedBy: staff._id }] });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const token = jwt.sign({ userId: staff._id }, process.env.JWT_SECRET);
    async function call(method, suffix, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/applications/${app._id}/assignment${suffix}`, { method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }
    await call('POST', '/requeue', { version: 0 });
    await call('PATCH', '', { advisorId: null, dueAt: null, version: 1 });
    let saved = await Application.findById(app._id);
    assert.equal(saved.autoAssignmentEligible, false, 'manual cancellation must revoke prior automatic-queue consent');
    assert.equal((await require('../src/utils/automaticApplicationAssignment').assignUnassignedApplications()).assigned, 0);
    for (const state of ['draft', 'final-admission', 'completed', 'rejected']) {
      saved.detailedStatus = state; await saved.save();
      await call('POST', '/requeue', { version: saved.__v }, 409);
      const view = await call('GET', '');
      assert.equal(view.application.canRequeue, false);
      assert.equal(view.application.isQueuedForAutomaticAssignment, false);
    }
    saved.detailedStatus = 'submitted'; await saved.save();
    assert.equal((await call('GET', '')).application.canRequeue, true);
    await call('POST', '/requeue', { version: saved.__v });
    assert.equal((await call('GET', '')).application.isQueuedForAutomaticAssignment, true);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
