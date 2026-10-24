const { test } = require('node:test');
const assert = require('node:assert/strict');
const { progress, restoreStreak, postReward, HOUR, monthKey } = require('../src/utils/storyRules');
test('exactly three restorations per calendar month; fourth remains zero and points stay intact', () => {
  const stats = { streak_days: 7, lastStoryAt: new Date('2026-10-01T00:00:00Z'), total_points: 3500 };
  let now = +stats.lastStoryAt;
  for (let i = 1; i <= 3; i++) {
    now += 37 * HOUR;
    assert.equal(restoreStreak(stats, now).streak_days, 7);
    assert.equal(progress(stats, now).streakRestoresRemaining, 3 - i);
    assert.throws(() => restoreStreak(stats, now), { statusCode: 409 });
  }
  const fourth = now + 37 * HOUR;
  assert.throws(() => restoreStreak(stats, fourth), { statusCode: 409 });
  assert.equal(progress(stats, fourth).streak_days, 0);
  assert.equal(stats.total_points, 3500);
  assert.equal(stats.streakRestoresUsed, 3);
  postReward(stats, fourth);
  assert.equal(stats.streak_days, 1);
  assert.equal(progress(stats, fourth).recoverableStreakDays, 0);
});
test('quota resets at Istanbul calendar month boundary and empty/active streaks cannot consume it', () => {
  const before = Date.parse('2026-10-31T20:59:59Z');
  const after = before + 1000;
  assert.equal(monthKey(before), '2026-10');
  assert.equal(monthKey(after), '2026-11');
  const stats = {
    streak_days: 12,
    lastStoryAt: new Date(before - 37 * HOUR),
    streakRestoreMonth: '2026-10',
    streakRestoresUsed: 3,
    total_points: 400,
  };
  assert.equal(progress(stats, before).restoreWindowOpen, true);
  assert.equal(restoreStreak(stats, after).streakRestoresRemaining, 2);
  assert.equal(stats.streakRestoresUsed, 1);
  assert.equal(stats.total_points, 400);
  assert.equal(progress(stats, after + 24 * HOUR).state, 'ice_cold');
  assert.equal(progress(stats, after + 36 * HOUR).streak_days, 0);
  assert.throws(() => restoreStreak({}, after), { statusCode: 409 });
});
test('monthly allowance reset never reopens an expired recovery window', () => {
  const boundary = Date.parse('2026-10-31T21:00:00Z');
  const stats = {
    streak_days: 0,
    brokenStreakDays: 12,
    lastStoryAt: new Date(boundary - 61 * HOUR),
    streakRestoreMonth: '2026-10',
    streakRestoresUsed: 3,
    total_points: 400,
  };
  const current = progress(stats, boundary);
  assert.equal(current.streakRestoresRemaining, 3);
  assert.equal(current.canRestoreStreak, false);
  assert.equal(current.streakState, 'expired');
  assert.throws(() => restoreStreak(stats, boundary), { statusCode: 409 });
  assert.equal(stats.streakRestoresUsed, 3);
  assert.equal(stats.total_points, 400);
});
test('game streak restoration consumes the shared quota without changing story history', () => {
  const now = Date.parse('2026-10-10T09:00:00Z');
  const lastStoryAt = new Date(now - 3 * 24 * HOUR);
  const stats = {
    streak_days: 2,
    lastStoryAt,
    gameStreakDays: 7,
    lastGameAt: new Date(now - 37 * HOUR),
    total_points: 1200,
  };
  assert.equal(restoreStreak(stats, now, 'game').streak_days, 7);
  assert.equal(stats.streakRestoresUsed, 1);
  assert.equal(progress(stats, now, 'game').streakRestoresRemaining, 2);
  assert.equal(stats.streak_days, 2);
  assert.equal(+stats.lastStoryAt, +lastStoryAt);
  assert.equal(stats.total_points, 1200);
});
