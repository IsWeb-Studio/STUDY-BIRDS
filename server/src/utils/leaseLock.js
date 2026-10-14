const { randomUUID } = require('node:crypto');
const WorkerLease = require('../models/WorkerLease');

// Short mutual-exclusion lease on a key (e.g. one student's wallet or one
// housing listing), stored in WorkerLease like the assignment scheduler's
// lease. Works on standalone MongoDB (no transactions needed). A crashed
// holder releases automatically when the lease expires.
async function acquire(key, owner, ms) {
  const now = new Date();
  try {
    return await WorkerLease.findOneAndUpdate(
      { _id: key, expiresAt: { $lte: now } },
      { $set: { owner, expiresAt: new Date(now.getTime() + ms) } },
      { upsert: true, new: true },
    );
  } catch (error) {
    if (error.code === 11000) return null; // someone else holds it
    throw error;
  }
}

class LeaseBusyError extends Error {
  constructor() {
    // The key is internal (ids); the client only needs to retry.
    super('Another request is in progress. Please retry in a moment.');
    this.statusCode = 409;
  }
}

// Runs fn while holding the lease; waits briefly for a concurrent holder.
async function withLease(key, fn, { ms = 15_000, waitMs = 3_000, renew = false } = {}) {
  const owner = randomUUID();
  const deadline = Date.now() + waitMs;
  let lease = await acquire(key, owner, ms);
  while (!lease && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 50 + Math.random() * 100));
    lease = await acquire(key, owner, ms);
  }
  if (!lease) throw new LeaseBusyError();
  const heartbeat = renew ? setInterval(() => {
    WorkerLease.updateOne({ _id: key, owner }, { $set: { expiresAt: new Date(Date.now() + ms) } }).catch(() => {});
  }, Math.max(1000, Math.floor(ms / 3))) : null;
  heartbeat?.unref();
  try {
    return await fn();
  } finally {
    if (heartbeat) clearInterval(heartbeat);
    await WorkerLease.updateOne({ _id: key, owner }, { $set: { expiresAt: new Date(0) } });
  }
}

module.exports = { withLease, LeaseBusyError };
