const { StoryStats } = require('../models/Stories');
const { dayKey } = require('../utils/storyRules');
const GAME_STREAK_HOURS = 36;
// A positive cache skips a write on every two-second room poll. The database
// remains authoritative across restarts, concurrent requests and replicas.
const credited = new Map();
function remember(id, day) {
  credited.set(id, day);
  if (credited.size > 10000) credited.delete(credited.keys().next().value);
}

// Called only after the server has accepted a real member's game action/read.
// Lobby, card reveal, old results, and simply opening the game earn nothing.
async function awardDailyGame(user, state, now = Date.now()) {
  const id = String(user._id);
  if (!['student', 'parent', 'university', 'employee', 'admin'].includes(user.role) ||
      state.practice || !['playing', 'voting'].includes(state.phase) ||
      state.players.filter(p => !p.left && !p.bot).length < 2 ||
      !state.players.some(p => p.id === id && !p.left && !p.bot)) return 0;
  const today = dayKey(now);
  if (credited.get(id) === today) return 0;
  if (user.role !== 'student') {
    const timestamp = new Date(now);
    const elapsed = { $subtract: [timestamp, { $ifNull: ['$lastGameAt', new Date(0)] }] };
    const expired = { $gte: [elapsed, GAME_STREAK_HOURS * 60 * 60 * 1000] };
    const nextDays = { $cond: [expired, 1, { $add: [{ $ifNull: ['$gameStreakDays', 0] }, 1] }] };
    try {
      await StoryStats.updateOne(
        { user: user._id, $or: [{ lastGameDay: { $lt: today } }, { lastGameDay: { $exists: false } }] },
        [{ $set: {
          gameStreakDays: nextDays,
          gameLongestStreak: { $max: [{ $ifNull: ['$gameLongestStreak', 0] }, { $ifNull: ['$gameStreakDays', 0] }, nextDays] },
          gameBrokenStreakDays: 0,
          gameActivityDays: { $slice: [{ $concatArrays: [{ $ifNull: ['$gameActivityDays', []] }, [today]] }, -35] },
          lastGameAt: timestamp,
          lastGameDay: today,
        } }],
        { upsert: true },
      );
      remember(id, today);
      return 0;
    } catch (error) {
      if (error.code === 11000 && error.keyPattern?.user) { remember(id, today); return 0; }
      throw error;
    }
  }
  try {
    const result = await StoryStats.updateOne({ user: user._id, $or: [
      { dailyGameDay: { $lt: today } }, { dailyGameDay: { $exists: false } },
    ] },
      { $inc: { total_points: 10 }, $set: { dailyGameDay: today } }, { upsert: true });
    remember(id, today);
    return result.modifiedCount || result.upsertedCount ? 10 : 0;
  } catch (error) {
    // The unique user index prevents a second document when the daily filter
    // no longer matches. Concurrent requests, rooms and retries award once.
    if (error.code === 11000 && error.keyPattern?.user) { remember(id, today); return 0; }
    throw error;
  }
}
module.exports = { awardDailyGame };
