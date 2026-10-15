const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('four authenticated players: rooms, CAS races, privacy, votes, reset and replay', async () => {
  process.env.JWT_SECRET = 'wink-integration-test-only';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Room = require('../src/models/WinkRoom');
    const { mutate, startWinkScheduler } = require('../src/games/winkStore');
    const users = await User.create(Array.from({ length: 5 }, (_, i) => ({ name: `Wink ${i}`, email: `wink${i}@example.test`, role: 'student' })));
    const app = require('../src/app');
    server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api/games/wink`;
    let counter = 0;
    async function request(route, index = 0, body, method = 'POST', auth = true) {
      const res = await fetch(base + route, { method, headers: {
        ...(auth ? { Authorization: `Bearer ${jwt.sign({ userId: users[index]._id }, process.env.JWT_SECRET)}` } : {}),
        'Content-Type': 'application/json',
        ...(body?.operationId ? { 'Idempotency-Key': body.operationId } : {}),
      }, ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: res.status, data: await res.json() };
    }
    assert.equal((await request('', 0, {}, 'POST', false)).status, 401);
    const created = await request('', 0, {}); assert.equal(created.status, 200);
    const code = created.data.code;
    assert.equal((await Room.findOne({ code }).lean()).state, undefined, 'stored secrets excluded by default');
    const action = (index, name, payload = {}, operationId = `operation-${++counter}`) => request(`/${code}/actions`, index, { action: name, payload, operationId });
    await Promise.all([1, 2, 3].map((i) => request(`/${code}/join`, i, {})));
    assert.equal((await request(`/${code}`, 4, null, 'GET')).status, 403);
    await Promise.all([0, 1, 2, 3].map((i) => action(i, 'ready', { ready: true })));
    assert.equal((await action(0, 'start')).data.phase, 'reveal');
    const roles = await Promise.all([0, 1, 2, 3].map((i) => request(`/${code}`, i, null, 'GET')));
    const killer = roles.findIndex((r) => r.data.me.role === 'winker');
    assert.ok(killer >= 0);
    assert.equal(roles.filter((r) => r.data.me.role === 'winker').length, 1);
    for (const role of roles) { assert.equal(role.data.winker, undefined); assert.equal(role.data.pending, undefined); }
    assert.equal((await request(`/${code}/join`, 4, {})).data.code, 'already-started');
    await Promise.all([0, 1, 2, 3].map((i) => action(i, 'seen')));
    const stale = await request(`/${code}/actions`, 0, { action: 'got-wink', round: 0, operationId: 'stale-round-001' });
    assert.equal(stale.data.code, 'stale-round');
    const normals = [0, 1, 2, 3].filter((i) => i !== killer);
    const target = String(users[normals[0]]._id);
    const concurrent = await Promise.all([action(normals[0], 'got-wink', {}, 'duplicate-wink-01'), action(normals[0], 'got-wink', {}, 'duplicate-wink-01')]);
    assert.ok(concurrent.every((r) => r.status === 200));
    let stored = await Room.findOne({ code }).select('+state').lean(); assert.equal(stored.state.pending.length, 1);
    // Accusation by the pending victim must settle their elimination, even if the accusation is rejected.
    assert.equal((await action(normals[0], 'accuse', { target: String(users[killer]._id) })).data.code, 'cannot-accuse');
    stored = await Room.findOne({ code }).select('+state').lean();
    assert.equal(stored.state.players.find((p) => p.id === target).eliminated, true);
    assert.equal(stored.state.pending.length, 0);
    const accused = String(users[killer]._id);
    const races = await Promise.all([action(normals[1], 'accuse', { target: accused }), action(normals[2], 'accuse', { target: accused })]);
    assert.equal(races.filter((r) => r.status === 200).length, 1);
    assert.equal((await action(killer, 'vote', { choice: 'yes' })).data.code, 'cannot-vote');
    await Promise.all(normals.slice(1).map((i) => action(i, 'vote', { choice: 'yes' })));
    const result = await request(`/${code}`, normals[1], null, 'GET');
    assert.equal(result.data.result.winner, 'players'); assert.equal(result.data.result.winker, accused);
    await action(0, 'reset');
    stored = await Room.findOne({ code }).select('+state').lean();
    assert.equal(stored.state.phase, 'lobby'); assert.equal(stored.state.winker, null);
    assert.ok(stored.state.players.every((p) => !p.seen && !p.ready && !p.accused && !p.eliminated));
    assert.equal(await require('../src/models/IdempotencyRecord').countDocuments(), 0,
      'private role responses must never enter the general response replay cache');
    // A server tick, without a host phone, handles a disconnected host.
    await mutate(code, (room, now) => { room.players[0].lastSeen = now - 60001; });
    const stop = startWinkScheduler();
    try { await new Promise((resolve) => setTimeout(resolve, 1500)); }
    finally { stop(); }
    stored = await Room.findOne({ code }).select('+state').lean();
    assert.notEqual(stored.state.host, String(users[0]._id));
    const training = await request('/practice', 0, { role: 'player' });
    assert.equal(training.status, 200); assert.equal(training.data.isPractice, true);
    assert.equal(training.data.phase, 'reveal');
    assert.equal(training.data.players.filter((p) => p.isBot).length, 3);
    assert.equal(training.data.me.role, 'player');
    assert.equal(training.data.practice, undefined);
    assert.equal(await User.countDocuments(), 5, 'bots never create fake authenticated accounts');
    const trainingCode = training.data.code;
    assert.equal((await request(`/${trainingCode}/join`, 4, {})).data.code, 'practice-private');
    assert.equal((await request(`/${trainingCode}`, 4, null, 'GET')).status, 403);
    const trainingAction = (name, payload = {}) => request(`/${trainingCode}/actions`, 0,
      { action: name, payload, operationId: `training-op-${++counter}`, round: 1 });
    assert.equal((await trainingAction('seen')).data.phase, 'playing');
    assert.equal((await trainingAction('practice-wink', { target: training.data.players.find((p) => p.isBot).id })).data.code, 'not-winker');
    assert.equal((await request('/practice', 0, {})).data.code, trainingCode, 'retries recover the same practice room');
    const realRoomTrainingAction = await request(`/${code}/actions`, 1,
      { action: 'practice-restart', payload: { role: 'winker' }, operationId: 'no-practice-on-real' });
    assert.equal(realRoomTrainingAction.data.code, 'practice-only');
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
