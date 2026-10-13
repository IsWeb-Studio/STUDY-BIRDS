const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
const User = require('../src/models/User');
const Application = require('../src/models/Application');
const WorkerLease = require('../src/models/WorkerLease');
const { assignUnassignedApplications: assign, startAutomaticAssignmentScheduler: scheduler } = require('../src/utils/automaticApplicationAssignment');

test('automatic admissions assignment on an isolated database', async t => {
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  try {
    await mongoose.connect(mongo.getUri());
    await Promise.all([User.init(), Application.init(), WorkerLease.init()]);
    let sequence = 0;
    const person = (overrides = {}) => User.create({ name: 'Advisor', email: `test${sequence++}@example.test`, role: 'employee', employeeRole: 'admission', permissions: ['applications'], ...overrides });
    const application = (overrides = {}) => Application.create({ student: new mongoose.Types.ObjectId(), program: new mongoose.Types.ObjectId(), university: new mongoose.Types.ObjectId(), ...overrides });
    const clear = () => Promise.all([User.deleteMany({}), Application.deleteMany({}), WorkerLease.deleteMany({})]);

    await t.test('balances active load, records automatic audit and deadline, and is idempotent', async () => {
      await clear();
      const a = await person(), b = await person();
      await application({ assignedAdvisor: a._id });
      const rows = await Promise.all([application(), application(), application()]);
      const start = Date.now();
      assert.equal((await assign({ maxLoad: 2, followUpHours: 12 })).assigned, 3);
      assert.equal(await Application.countDocuments({ assignedAdvisor: a._id }), 2);
      assert.equal(await Application.countDocuments({ assignedAdvisor: b._id }), 2);
      for (const row of rows) {
        const saved = await Application.findById(row._id);
        assert.equal(saved.status, 'submitted');
        assert.equal(saved.__v, 1);
        assert.equal(saved.assignmentHistory.length, 1);
        assert.equal(saved.assignmentHistory[0].source, 'automatic');
        assert.equal(saved.assignmentHistory[0].changedBy, undefined);
        assert.ok(saved.followUpDueAt.getTime() >= start + 12 * 3600000);
        assert.ok(saved.followUpDueAt.getTime() <= Date.now() + 12 * 3600000);
      }
      assert.equal((await assign()).assigned, 0);
    });

    await t.test('excludes inactive, unauthorized and non-admissions users, drafts and closed or manually cleared cases', async () => {
      await clear();
      await person({ isActive: false });
      await person({ permissions: [] });
      await person({ employeeRole: 'finance' });
      await person({ role: 'admin' });
      const pending = await application();
      assert.equal((await assign()).assigned, 0);
      const advisor = await person();
      const protectedRows = await Promise.all([
        application({ detailedStatus: 'draft' }),
        application({ detailedStatus: 'rejected' }),
        application({ detailedStatus: 'completed' }),
        application({ detailedStatus: 'final-admission' }),
        application({ assignmentHistory: [{ advisor: null, changedBy: advisor._id }] }),
      ]);
      const manual = await application({ assignedAdvisor: advisor._id });
      assert.equal((await assign()).assigned, 1);
      assert.ok((await Application.findById(pending._id)).assignedAdvisor);
      for (const row of protectedRows) assert.equal((await Application.findById(row._id)).assignedAdvisor, null);
      assert.equal((await Application.findById(manual._id)).assignmentHistory.length, 0);
    });

    await t.test('concurrent workers respect capacity and a live lease; expired leases recover', async () => {
      await clear();
      const advisor = await person();
      await Promise.all(Array.from({ length: 8 }, () => application()));
      await Promise.all([assign({ maxLoad: 3 }), assign({ maxLoad: 3 }), assign({ maxLoad: 3 })]);
      assert.equal(await Application.countDocuments({ assignedAdvisor: advisor._id }), 3);
      await WorkerLease.updateOne({ _id: 'automatic-admission-assignment' }, { $set: { owner: 'another-worker', expiresAt: new Date(Date.now() + 60000) } });
      assert.equal((await assign()).skipped, 'worker-busy');
      await WorkerLease.updateOne({ _id: 'automatic-admission-assignment' }, { $set: { expiresAt: new Date(0) } });
      assert.equal((await assign({ maxLoad: 10, batchSize: 2 })).assigned, 2);
    });

    await t.test('a manual edit racing the scan wins without a duplicate audit event', async () => {
      await clear();
      const advisor = await person(), manualAdvisor = await person({ employeeRole: 'finance' });
      const row = await application();
      const original = Application.updateOne;
      let intercepted = false;
      Application.updateOne = async function (filter, update, options) {
        if (!intercepted && update.$push?.assignmentHistory?.source === 'automatic') {
          intercepted = true;
          await original.call(this, { _id: row._id }, {
            $set: { assignedAdvisor: manualAdvisor._id }, $inc: { __v: 1 },
            $push: { assignmentHistory: { advisor: manualAdvisor._id, source: 'manual', changedBy: advisor._id } },
          });
        }
        return original.call(this, filter, update, options);
      };
      try { assert.equal((await assign()).assigned, 0); }
      finally { Application.updateOne = original; }
      const saved = await Application.findById(row._id);
      assert.equal(String(saved.assignedAdvisor), String(manualAdvisor._id));
      assert.equal(saved.assignmentHistory.length, 1);
      assert.equal(saved.assignmentHistory[0].source, 'manual');
    });

    await t.test('stops if lease ownership is lost before writing', async () => {
      await clear(); await person(); const row = await application();
      const original = WorkerLease.updateOne;
      WorkerLease.updateOne = function (filter, update, options) {
        if (filter.expiresAt) return Promise.resolve({ matchedCount: 0 });
        return original.call(this, filter, update, options);
      };
      try { assert.equal((await assign()).skipped, 'lease-lost'); }
      finally { WorkerLease.updateOne = original; }
      assert.equal((await Application.findById(row._id)).assignedAdvisor, null);
    });

    await t.test('disabled scheduler does not run and invalid settings fail before writing', async () => {
      let called = false;
      scheduler({ enabled: false, run: async () => { called = true; } })();
      await new Promise(resolve => setImmediate(resolve));
      assert.equal(called, false);
      for (const options of [{ intervalMs: 10 }, { maxLoad: 0 }, { followUpHours: NaN }, { batchSize: -1 }]) {
        assert.throws(() => scheduler({ enabled: true, ...options }));
      }
      await assert.rejects(assign({ maxLoad: 1.5 }));
    });
  } finally {
    await mongoose.disconnect(); await mongo.stop();
  }
});
