const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('game activity: real multiplayer, daily limit, races, streak and role eligibility', async () => {
  process.env.JWT_SECRET = 'wink-reward-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger', ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Room = require('../src/models/WinkRoom');
    const { StoryStats } = require('../src/models/Stories');
    const { Session } = require('../src/models/MobileWorkspace');
    const { awardDailyGame } = require('../src/games/winkRewards');
    const engine = require('../src/games/winkEngine');
    const { dayKey, progress } = require('../src/utils/storyRules');
    await Promise.all([User.init(), Room.init(), StoryStats.init(), Session.init()]);
    const users = await User.create(Array.from({ length: 6 }, (_, i) => ({ name: `Reward ${i}`, email: `reward${i}@example.test`, role: i === 5 ? 'parent' : 'student' })));
    const ids = users.map(u => ({ id: String(u._id), name: u.name }));
    const now = Date.now();
    const state = engine.newRoom(ids[0], now);
    for (const u of ids.slice(1, 4)) engine.join(state, u, now);
    for (const u of ids.slice(0, 4)) engine.apply(state, u, 'ready', { ready: true }, now);
    engine.apply(state, ids[0], 'start', {}, now);
    const doc = await Room.create({ code: engine.code(), state, expiresAt: new Date(now + 86400000) });
    const app = express(); app.use(express.json()); app.use('/wink', require('../src/routes/winkRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    let serial = 0;
    async function call(i, action) {
      const r = await fetch(`http://127.0.0.1:${server.address().port}/wink/${doc.code}${action ? '/actions' : ''}`, {
        method: action ? 'POST' : 'GET', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ userId: users[i]._id }, process.env.JWT_SECRET)}` },
        ...(action ? { body: JSON.stringify({ action, operationId: `reward-action-${++serial}` }) } : {}),
      });
      return { status: r.status, data: await r.json() };
    }
    assert.equal((await call(0)).data.pointsAwarded, 0, 'reveal is not play');
    assert.equal(await StoryStats.countDocuments(), 0);
    for (let i = 0; i < 4; i++) assert.equal((await call(i, 'seen')).status, 200);
    assert.equal((await call(4)).status, 403, 'nonmembers cannot claim');
    const concurrent = await Promise.all(Array.from({ length: 8 }, () => call(0)));
    concurrent.forEach(r => assert.equal(r.status, 200, JSON.stringify(r)));
    assert.equal(concurrent.reduce((sum, r) => sum + r.data.pointsAwarded, 0), 10);
    let stats = await StoryStats.findOne({ user: users[0]._id }).lean();
    assert.equal(stats.total_points, 10);
    assert.equal(stats.streak_days, 0);
    assert.equal(stats.lastStoryAt, undefined);
    assert.equal(progress(stats).playedToday, true);
    // Another real play on the next business day awards exactly ten more.
    const active = (await Room.findById(doc._id).select('+state').lean()).state;
    const tomorrow = now + 86400000;
    assert.notEqual(dayKey(now), dayKey(tomorrow));
    const nextDay = await Promise.all(Array.from({ length: 6 }, () => awardDailyGame(users[0], active, tomorrow)));
    assert.equal(nextDay.reduce((a, b) => a + b, 0), 10);
    stats = await StoryStats.findOne({ user: users[0]._id }).lean();
    assert.equal(stats.total_points, 20);
    assert.equal(stats.streak_days, 0);
    assert.equal(await awardDailyGame(users[0], active, now), 0, 'a delayed previous-day request cannot award again');
    const fake = { ...active, players: [...active.players, { id: String(users[5]._id) }] };
    assert.equal(await awardDailyGame(users[5], fake, tomorrow), 0);
    const parentGame = {
      ...active,
      players: [...active.players, { id: String(users[5]._id), left: false, bot: false }],
    };
    assert.equal(await awardDailyGame(users[5], parentGame, tomorrow), 0,
      'non-student online activity advances streak but grants no game points');
    let parentStats = await StoryStats.findOne({ user: users[5]._id }).lean();
    assert.equal(parentStats.gameStreakDays, 1);
    assert.equal(parentStats.gameActivityDays.length, 1);
    assert.equal(await awardDailyGame(users[5], parentGame, tomorrow + 1000), 0,
      'one activity per calendar day');
    assert.equal(await awardDailyGame(users[5], parentGame, tomorrow + 24 * 60 * 60 * 1000), 0);
    parentStats = await StoryStats.findOne({ user: users[5]._id }).lean();
    assert.equal(parentStats.gameStreakDays, 2);
    assert.equal(parentStats.total_points || 0, 0);
    assert.equal(await awardDailyGame(users[5], { ...parentGame, practice: { owner: String(users[5]._id) } }, tomorrow + 48 * 60 * 60 * 1000), 0,
      'practice play never advances a streak');
    parentStats = await StoryStats.findOne({ user: users[5]._id }).lean();
    assert.equal(parentStats.gameStreakDays, 2);
    for (const phase of ['lobby', 'reveal', 'finished', 'closed']) {
      assert.equal(await awardDailyGame(users[4], { ...active, phase }, tomorrow), 0);
    }
    assert.equal(await StoryStats.countDocuments({ user: users[4]._id }), 0,
      'a student who never participated still has no reward record');
    assert.equal(await StoryStats.countDocuments({ user: users[5]._id }), 1,
      'the parent game streak belongs to the parent account');
    const balances = [99999, 100000, 199999, 200000].map(total_points => progress({ total_points }, now));
    assert.equal(balances[0].ringTier, 'orange'); assert.equal(balances[1].ringTier, 'elite');
    assert.equal(balances[2].cosmeticVerified, false); assert.equal(balances[3].cosmeticVerified, true);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
