const { test } = require('node:test');
const assert = require('node:assert/strict');
const { HOUR, progress, postReward, storyReward, storyPostReward, loveReward, dayKey } = require('../src/utils/storyRules');
const start = Date.parse('2026-10-01T09:00:00Z');
test('first daily story earns 100; extra stories refresh deadline without extra days or points', () => {
  const stats = {};
  assert.equal(postReward(stats, start), 100);
  assert.equal(postReward(stats, start + HOUR), 0);
  assert.equal(stats.streak_days, 1);
  assert.equal(stats.total_points, 100);
  assert.equal(+stats.lastStoryAt, start + HOUR);
});
test('24h freezes, 36h resets days only; posting in grace preserves the streak', () => {
  const stats = {};
  postReward(stats, start);
  assert.equal(progress(stats, start + 24 * HOUR - 1).state, 'active');
  assert.equal(progress(stats, start + 24 * HOUR).state, 'ice_cold');
  assert.equal(progress(stats, start + 36 * HOUR - 1).streak_days, 1);
  assert.equal(progress(stats, start + 36 * HOUR).streak_days, 0);
  assert.equal(progress(stats, start + 36 * HOUR).total_points, 100);
  const grace = { ...stats };
  postReward(grace, start + 30 * HOUR);
  assert.equal(grace.streak_days, 2);
  postReward(stats, start + 36 * HOUR);
  assert.equal(stats.streak_days, 1);
  assert.equal(stats.total_points, 200);
});
test('bonuses repeat at days 7 and 14, never again for an extra story that day', () => {
  const stats = {};
  for (let i = 0; i < 14; i++) {
    const expected = (i + 1) % 7 === 0 ? 400 : 100;
    assert.equal(postReward(stats, start + i * 24 * HOUR), expected);
    assert.equal(postReward(stats, start + i * 24 * HOUR + 1000), 0);
  }
  assert.equal(stats.total_points, 2000);
  assert.equal(stats.streak_days, 14);
});
test('calendar rollover uses Istanbul, giver capped at 10 and reset next local day', () => {
  const before = Date.parse('2026-10-01T20:59:59Z'), after = before + 1000;
  assert.notEqual(dayKey(before), dayKey(after));
  const stats = {};
  for (let i = 0; i < 15; i++) assert.equal(loveReward(stats, before), i < 10 ? 5 : 0);
  assert.equal(stats.total_points, 50);
  assert.equal(loveReward(stats, after), 5);
  assert.equal(stats.dailyLoveCount, 1);
  const posts = {}; postReward(posts, before); postReward(posts, after);
  assert.equal(posts.streak_days, 2);
  assert.equal(posts.total_points, 200);
});
test('orange achievement persists after streak break, exact threshold', () => {
  assert.equal(progress({ total_points: 9999 }, start).ringUnlocked, false);
  assert.equal(progress({ total_points: 10000, streak_days: 7, lastStoryAt: new Date(start) }, start + 40 * HOUR).ringUnlocked, true);
});
test('non-student story points are awarded once per local day without advancing the game streak', () => {
  const stats = { gameStreakDays: 4, lastGameAt: new Date(start), total_points: 25 };
  assert.equal(storyReward(stats, start), 100);
  assert.equal(storyReward(stats, start + HOUR), 0);
  assert.equal(stats.total_points, 125);
  assert.equal(stats.gameStreakDays, 4);
  assert.equal(+stats.lastGameAt, start);
  assert.equal(progress(stats, start, 'game').postedToday, true);
  assert.equal(progress(stats, start, 'game').playedToday, false);
});
test('story posting awards points only to community roles while agent remains excluded', () => {
  const now = start + 10 * 24 * HOUR;
  const student = {};
  assert.equal(storyPostReward(student, now, 'student'), 100);
  assert.equal(student.streak_days, 1);
  for (const role of ['parent', 'university', 'employee', 'admin']) {
    const stats = { gameStreakDays: 5 };
    assert.equal(storyPostReward(stats, now, role), 100, `${role} receives story points`);
    assert.equal(stats.total_points, 100);
    assert.equal(stats.gameStreakDays, 5, `${role}'s story must not advance game streak`);
  }
  const agent = {};
  assert.equal(storyPostReward(agent, now, 'agent'), 0);
  assert.equal(agent.total_points, undefined);
});
test('game-source progress reads game activity and preserves separate story progress', () => {
  const stats = {
    streak_days: 9,
    lastStoryAt: new Date(start),
    gameStreakDays: 3,
    gameLongestStreak: 5,
    gameActivityDays: [dayKey(start - 24 * HOUR), dayKey(start)],
    lastGameDay: dayKey(start),
    lastGameAt: new Date(start),
  };
  const result = progress(stats, start, 'game');
  assert.equal(result.streak_days, 3);
  assert.equal(result.longestStreak, 5);
  assert.equal(result.activityCalendar.at(-1).active, true);
  assert.equal(result.activityCalendar.at(-2).active, true);
  assert.equal(stats.streak_days, 9);
});
