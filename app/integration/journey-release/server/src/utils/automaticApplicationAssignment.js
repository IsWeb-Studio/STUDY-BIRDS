const { randomUUID } = require('node:crypto');
const mongoose = require('mongoose');
const Application = require('../models/Application');
const User = require('../models/User');
const WorkerLease = require('../models/WorkerLease');
const { assignmentStageFilter } = require('./automaticAssignmentEligibility');

const LEASE_ID = 'automatic-admission-assignment';
const LEASE_MS = 60000;
const eligibleAdvisor = {
  role: 'employee', isActive: true, permissions: 'applications',
  employeeRole: { $in: ['admission', 'admission_manager', 'educational_consultant'] },
};
const openApplication = {
  status: { $nin: ['rejected', 'file-completed-rejected', 'file-completed-accepted'] },
  detailedStatus: { $nin: ['rejected', 'completed'] },
};
const candidateApplication = {
  assignedAdvisor: null,
  // A cleared manual assignment stays out of the queue unless staff explicitly
  // re-queues it (autoAssignmentEligible) — see requeueAssignment.
  $or: [{ 'assignmentHistory.0': { $exists: false } }, { autoAssignmentEligible: true }],
  ...assignmentStageFilter,
};

function positiveInteger(value, name, maximum) {
  if (!Number.isSafeInteger(value) || value < 1 || value > maximum) {
    throw new Error(`${name} must be an integer between 1 and ${maximum}`);
  }
  return value;
}

async function acquireLease(owner) {
  const now = new Date();
  try {
    return await WorkerLease.findOneAndUpdate(
      { _id: LEASE_ID, expiresAt: { $lte: now } },
      { $set: { owner, expiresAt: new Date(now.getTime() + LEASE_MS) } },
      { upsert: true, new: true },
    );
  } catch (error) {
    if (error.code === 11000) return null;
    throw error;
  }
}

async function renewLease(owner) {
  const now = new Date();
  const result = await WorkerLease.updateOne(
    { _id: LEASE_ID, owner, expiresAt: { $gt: now } },
    { $set: { expiresAt: new Date(now.getTime() + LEASE_MS) } },
  );
  return result.matchedCount === 1;
}

async function assignUnassignedApplications({ maxLoad = 20, followUpHours = 48, batchSize = 100 } = {}) {
  positiveInteger(maxLoad, 'maxLoad', 10000);
  positiveInteger(followUpHours, 'followUpHours', 720);
  positiveInteger(batchSize, 'batchSize', 1000);
  const owner = randomUUID();
  if (!await acquireLease(owner)) return { assigned: 0, skipped: 'worker-busy' };
  let assigned = 0;
  try {
    const candidates = await Application.find(candidateApplication)
      .sort({ createdAt: 1, _id: 1 }).limit(batchSize).select('_id __v status detailedStatus').lean();
    for (const application of candidates) {
      if (!await renewLease(owner)) return { assigned, skipped: 'lease-lost' };
      const advisors = await User.find(eligibleAdvisor).select('_id').sort({ _id: 1 }).lean();
      if (!advisors.length) break;
      const loads = await Application.aggregate([
        { $match: { ...openApplication, assignedAdvisor: { $in: advisors.map(a => a._id) } } },
        { $group: { _id: '$assignedAdvisor', count: { $sum: 1 } } },
      ]);
      const counts = new Map(loads.map(row => [String(row._id), row.count]));
      advisors.sort((a, b) => (counts.get(String(a._id)) || 0) - (counts.get(String(b._id)) || 0)
        || String(a._id).localeCompare(String(b._id)));
      const advisor = advisors.find(a => (counts.get(String(a._id)) || 0) < maxLoad);
      if (!advisor) break;
      if (!await User.exists({ ...eligibleAdvisor, _id: advisor._id })) continue;
      if (!await renewLease(owner)) return { assigned, skipped: 'lease-lost' };
      const now = new Date();
      const dueAt = new Date(now.getTime() + followUpHours * 3600000);
      // Compare-and-swap protects manual changes and status changes made during the scan.
      const result = await Application.updateOne({
        ...candidateApplication, _id: application._id, __v: application.__v,
        status: application.status, detailedStatus: application.detailedStatus,
      }, {
        $set: { assignedAdvisor: advisor._id, followUpDueAt: dueAt, autoAssignmentEligible: false },
        $inc: { __v: 1 },
        $push: { assignmentHistory: { advisor: advisor._id, dueAt, changedAt: now, source: 'automatic' } },
      }, { runValidators: true });
      assigned += result.modifiedCount;
    }
    return { assigned };
  } finally {
    await WorkerLease.updateOne({ _id: LEASE_ID, owner }, { $set: { expiresAt: new Date(0) } });
  }
}

function startAutomaticAssignmentScheduler({
  enabled = process.env.AUTO_ASSIGNMENT_ENABLED === 'true',
  intervalMs = Number(process.env.AUTO_ASSIGNMENT_INTERVAL_MS || 300000),
  maxLoad = Number(process.env.AUTO_ASSIGNMENT_MAX_OPEN || 20),
  followUpHours = Number(process.env.AUTO_ASSIGNMENT_DUE_HOURS || 48),
  batchSize = Number(process.env.AUTO_ASSIGNMENT_BATCH_SIZE || 100),
  run = assignUnassignedApplications,
} = {}) {
  if (!enabled) return () => {};
  positiveInteger(intervalMs, 'intervalMs', 86400000);
  if (intervalMs < 60000) throw new Error('intervalMs must be at least 60000');
  positiveInteger(maxLoad, 'maxLoad', 10000);
  positiveInteger(followUpHours, 'followUpHours', 720);
  positiveInteger(batchSize, 'batchSize', 1000);
  let running = false, stopped = false;
  const tick = async () => {
    if (running || stopped || mongoose.connection.readyState !== 1) return;
    running = true;
    try { await run({ maxLoad, followUpHours, batchSize }); }
    catch (error) { console.error('Automatic assignment scan failed', error.name); }
    finally { running = false; }
  };
  const timer = setInterval(tick, intervalMs);
  timer.unref();
  void tick();
  return () => { stopped = true; clearInterval(timer); };
}

module.exports = { assignUnassignedApplications, startAutomaticAssignmentScheduler };
