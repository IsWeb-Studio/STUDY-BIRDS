const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('agent credits, reservations and payouts are scoped, concurrent-safe and never debited twice', async () => {
  process.env.JWT_SECRET = 'agent-wallet-lifecycle';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Entry = require('../src/models/AgentWalletEntry');
    const Payout = require('../src/models/PayoutRequest');
    const admin = await User.create({ name: 'Admin', email: 'admin@test.example', role: 'admin' });
    const agent = await User.create({ name: 'Agent', email: 'agent@test.example', role: 'partner' });
    const other = await User.create({ name: 'Other', email: 'other@test.example', role: 'partner' });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, endpoint, user, body, key) {
      const res = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}`, 'Content-Type': 'application/json', ...(key ? { 'Idempotency-Key': key } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      return { status: res.status, data: await res.json() };
    }
    const adjustment = { studentId: String(agent._id), amount: 100, direction: 'credit', notes: 'Approved commission' };
    const adjustPath = '/admin/payout-requests/wallet-entries';
    assert.equal((await call('POST', adjustPath, agent, adjustment)).status, 403);
    assert.equal((await call('POST', adjustPath, admin, adjustment, 'credit-001')).status, 201);
    await require('../src/models/IdempotencyRecord').deleteMany({});
    assert.equal((await call('POST', adjustPath, admin, adjustment, 'credit-001')).status, 201);
    assert.equal(await Entry.countDocuments(), 1);
    const wallet = async () => (await call('GET', '/partners/wallet', agent)).data.summary;
    assert.equal((await wallet()).availableBalance, 100);
    assert.equal((await call('GET', '/partners/wallet', other)).data.summary.availableBalance, 0);
    const payload = { amount: 80, method: 'bank-account', payoutDetails: 'Account details', notes: '' };
    const results = await Promise.all([call('POST', '/partners/wallet/payout-requests', agent, payload, 'withdraw1'), call('POST', '/partners/wallet/payout-requests', agent, payload, 'withdraw2')]);
    assert.deepEqual(results.map(r => r.status).sort(), [201, 409]);
    let request = results.find(r => r.status === 201).data;
    assert.equal((await wallet()).availableBalance, 20); assert.equal((await wallet()).reservedBalance, 80);
    assert.equal((await call('POST', adjustPath, admin, { ...adjustment, amount: 21, direction: 'debit' })).status, 409);
    assert.equal((await call('PATCH', `/admin/payout-requests/${request._id}`, admin, { status: 'rejected' })).status, 200);
    assert.equal((await wallet()).availableBalance, 100);
    request = (await call('POST', '/partners/wallet/payout-requests', agent, payload, 'withdraw3')).data;
    assert.equal((await call('PATCH', `/admin/payout-requests/${request._id}`, admin, { status: 'approved' })).status, 200);
    for (let i = 0; i < 2; i++) assert.equal((await call('PATCH', `/admin/payout-requests/${request._id}`, admin, { status: 'paid' })).status, 200);
    assert.equal(await Entry.countDocuments({ direction: 'debit', kind: 'payout' }), 1);
    assert.equal((await wallet()).availableBalance, 20); assert.equal((await wallet()).reservedBalance, 0);
    assert.equal((await wallet()).receivedBalance, 80);
    assert.equal((await call('PATCH', `/admin/payout-requests/${request._id}`, admin, { status: 'pending' })).status, 409);
    for (const amount of [Infinity, -1, 1.001]) assert.equal((await call('POST', '/partners/wallet/payout-requests', agent, { ...payload, amount })).status, 400);
    assert.equal(await Payout.countDocuments(), 2);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
