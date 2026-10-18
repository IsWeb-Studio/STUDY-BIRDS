const { test } = require('node:test');
const assert = require('node:assert/strict');
const { progress, restoreStreak, postReward, HOUR, monthKey } = require('../src/utils/storyRules');
test('exactly three restorations per calendar month; fourth remains zero and points stay intact', () => {
  const stats = { streak_days: 7, lastStoryAt: new Date('2026-10-01T00:00:00Z'), total_points: 3500 };
  for (let i = 1; i <= 3; i++) {
    const now = Date.parse(`2026-10-${String(i * 3).padStart(2, '0')}T00:00:00Z`);
    assert.equal(restoreStreak(stats, now).streak_days, 7);
    assert.equal(progress(stats, now).streakRestoresRemaining, 3 - i);
    assert.throws(() => restoreStreak(stats, now), { statusCode: 409 });
  }
  const fourth = Date.parse('2026-10-12T00:00:00Z');
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
  const stats = { streak_days: 0, brokenStreakDays: 12, streakRestoreMonth: '2026-10', streakRestoresUsed: 3, total_points: 400 };
  assert.throws(() => restoreStreak(stats, before), { statusCode: 409 });
  assert.equal(restoreStreak(stats, after).streakRestoresRemaining, 2);
  assert.equal(stats.streakRestoresUsed, 1);
  assert.equal(stats.total_points, 400);
  assert.equal(progress(stats, after + 24 * HOUR).state, 'ice_cold');
  assert.equal(progress(stats, after + 36 * HOUR).streak_days, 0);
  assert.throws(() => restoreStreak({}, after), { statusCode: 409 });
});
