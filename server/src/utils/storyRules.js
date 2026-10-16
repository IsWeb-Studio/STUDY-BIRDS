const HOUR = 3600000;
const SCORE_EMOJIS = ['🔥', '⭐', '🌟', '🏆', '🚀', '💎', '🦅', '📚', '🎯', '⚡', '❤️', '🌱'];
const TIME_ZONE = process.env.STORY_TIME_ZONE || 'Europe/Istanbul';
const formatter = new Intl.DateTimeFormat('en-CA', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' });
const dayKey = (now) => formatter.format(new Date(now));
function progress(stats = {}, now = Date.now()) {
  const age = stats.lastStoryAt ? now - new Date(stats.lastStoryAt).getTime() : Infinity;
  const streak = age >= 36 * HOUR ? 0 : (stats.streak_days || 0);
  const points = stats.total_points || 0;
  return {
    total_points: points, streak_days: streak,
    scoreEmoji: SCORE_EMOJIS.includes(stats.scoreEmoji) ? stats.scoreEmoji : '🔥',
    ringTier: points >= 100000 ? 'elite' : points >= 10000 ? 'orange' : 'basic',
    cosmeticVerified: points >= 200000,
    playedToday: stats.dailyGameDay === dayKey(now),
    state: streak === 0 ? 'inactive' : age >= 24 * HOUR ? 'ice_cold' : 'active',
    freezesAt: streak ? new Date(+new Date(stats.lastStoryAt) + 24 * HOUR) : null,
    resetsAt: streak ? new Date(+new Date(stats.lastStoryAt) + 36 * HOUR) : null,
    postedToday: stats.lastPostDay === dayKey(now),
    dailyLoveCount: stats.dailyLoveDay === dayKey(now) ? stats.dailyLoveCount || 0 : 0,
    ringUnlocked: points >= 10000, ringTarget: 10000, timeZone: TIME_ZONE,
  };
}
function postReward(stats, now) {
  const today = dayKey(now);
  const before = progress(stats, now);
  // A new streak can start even on the same calendar day after an actual break.
  const increment = !before.streak_days || stats.lastPostDay !== today;
  stats.streak_days = before.streak_days + (increment ? 1 : 0);
  let points = stats.lastPostDay === today ? 0 : 100;
  if (increment && stats.streak_days % 7 === 0) points += 300;
  stats.total_points = (stats.total_points || 0) + points;
  stats.lastStoryAt = new Date(now);
  stats.lastPostDay = today;
  return points;
}
function loveReward(stats, now) {
  const today = dayKey(now);
  if (stats.dailyLoveDay !== today) { stats.dailyLoveDay = today; stats.dailyLoveCount = 0; }
  const points = stats.dailyLoveCount < 10 ? 5 : 0;
  stats.dailyLoveCount = Math.min(10, stats.dailyLoveCount + 1);
  stats.total_points = (stats.total_points || 0) + points;
  return points;
}
module.exports = { HOUR, TIME_ZONE, SCORE_EMOJIS, dayKey, progress, postReward, loveReward };
