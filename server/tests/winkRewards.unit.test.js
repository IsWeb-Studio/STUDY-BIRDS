const { test } = require('node:test');
const assert = require('node:assert/strict');

const modelPath = require.resolve('../src/models/Stories');
const updates = [];
require.cache[modelPath] = {
  id: modelPath,
  filename: modelPath,
  loaded: true,
  exports: {
    StoryStats: {
      async updateOne(filter, update, options) {
        updates.push({ filter, update, options });
        return { modifiedCount: 1, upsertedCount: 0 };
      },
    },
  },
};
const { awardDailyGame } = require('../src/games/winkRewards');

test('eligible non-student real online activity writes only the game streak fields once per day', async () => {
  const id = 'synthetic-admin-wink-streak';
  const now = Date.parse('2030-04-01T08:00:00Z');
  const state = {
    phase: 'playing',
    players: [
      { id, left: false, bot: false },
      { id: 'synthetic-human-opponent', left: false, bot: false },
    ],
  };
  assert.equal(await awardDailyGame({ _id: id, role: 'admin' }, state, now), 0);
  assert.equal(updates.length, 1);
  const [{ filter, update, options }] = updates;
  assert.equal(filter.user, id);
  assert.equal(options.upsert, true);
  assert.ok(Array.isArray(update), 'uses a server-side atomic pipeline');
  assert.ok(update[0].$set.gameStreakDays);
  assert.ok(update[0].$set.gameLongestStreak);
  assert.ok(update[0].$set.gameActivityDays);
  assert.ok(update[0].$set.lastGameAt);
  assert.ok(update[0].$set.lastGameDay);
  assert.equal(await awardDailyGame({ _id: id, role: 'admin' }, state, now + 1000), 0);
  assert.equal(updates.length, 1, 'a repeated request cannot advance the day twice');
});

test('agents, practice, non-playing phases and games without two humans cannot advance streaks', async () => {
  updates.length = 0;
  const id = 'synthetic-ineligible-wink-user';
  const base = {
    phase: 'playing',
    players: [
      { id, left: false, bot: false },
      { id: 'synthetic-bot', left: false, bot: true },
    ],
  };
  const now = Date.parse('2030-04-02T08:00:00Z');
  assert.equal(await awardDailyGame({ _id: id, role: 'agent' }, base, now), 0);
  assert.equal(await awardDailyGame({ _id: id, role: 'admin' }, { ...base, practice: true }, now), 0);
  assert.equal(await awardDailyGame({ _id: id, role: 'admin' }, { ...base, phase: 'lobby' }, now), 0);
  assert.equal(updates.length, 0);
});

test('student daily game reward remains points-only and does not advance the story streak', async () => {
  updates.length = 0;
  const id = 'synthetic-student-wink-points';
  const now = Date.parse('2030-04-03T08:00:00Z');
  const state = {
    phase: 'playing',
    players: [
      { id, left: false, bot: false },
      { id: 'synthetic-student-opponent', left: false, bot: false },
    ],
  };
  assert.equal(await awardDailyGame({ _id: id, role: 'student' }, state, now), 10);
  const update = updates.at(-1).update;
  assert.equal(update.$inc.total_points, 10);
  assert.equal(update.$set.dailyGameDay, '2030-04-03');
  assert.equal(update.$set.gameStreakDays, undefined);
});
