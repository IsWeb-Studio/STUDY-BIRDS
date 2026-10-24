const HOUR = 3600000;
const SCORE_EMOJIS = ['🔥', '⭐', '🌟', '🏆', '🚀', '💎', '🦅', '📚', '🎯', '⚡', '❤️', '🌱'];
const TIME_ZONE = process.env.STORY_TIME_ZONE || 'Europe/Istanbul';
const formatter = new Intl.DateTimeFormat('en-CA', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' });
const dayKey = (now) => formatter.format(new Date(now));
const monthKey = now => {
  const parts = formatter.formatToParts(new Date(now));
  return `${parts.find(p => p.type === 'year').value}-${parts.find(p => p.type === 'month').value}`;
};
const RESTORES_PER_MONTH = 3;
let cachedMonth, cachedReset;
function monthResetsAt(now) {
  const key = monthKey(now);
  if (cachedMonth !== key) {
    let low = now, high = now + 35 * 24 * HOUR;
    while (high - low > 1) {
      const mid = Math.floor((low + high) / 2);
      if (monthKey(mid) === key) low = mid; else high = mid;
    }
    cachedMonth = key; cachedReset = high;
  }
  return new Date(cachedReset);
}
const STREAK_FIELDS = Object.freeze({
  story: { days: 'streak_days', broken: 'brokenStreakDays', longest: 'longestStreak', activity: 'activityDays', at: 'lastStoryAt', day: 'lastPostDay' },
  game: { days: 'gameStreakDays', broken: 'gameBrokenStreakDays', longest: 'gameLongestStreak', activity: 'gameActivityDays', at: 'lastGameAt', day: 'lastGameDay' },
});
function fieldsFor(source = 'story') {
  const fields = STREAK_FIELDS[source];
  if (!fields) throw new TypeError('Unknown streak source');
  return fields;
}
function calendar(stats, now, fields, count = 35) {
  const today = dayKey(now), end = Date.parse(today + 'T00:00:00Z');
  const active = new Set([...(stats[fields.activity] || []), stats[fields.day]].filter(Boolean));
  return Array.from({ length: count }, (_, i) => {
    const day = new Date(end - (count - 1 - i) * 24 * HOUR).toISOString().slice(0, 10);
    return { day, active: active.has(day) };
  });
}
function expireStreak(stats, now, source = 'story') {
  const fields = fieldsFor(source);
  if (stats[fields.days] > 0 && stats[fields.at] && now - new Date(stats[fields.at]).getTime() >= 36 * HOUR) {
    stats[fields.broken] = stats[fields.days];
    stats[fields.longest] = Math.max(stats[fields.longest] || 0, stats[fields.days]);
    stats[fields.days] = 0;
  }
}
function progress(stats = {}, now = Date.now(), source = 'story') {
  const fields = fieldsFor(source);
  const age = stats[fields.at] ? now - new Date(stats[fields.at]).getTime() : Infinity;
  const streak = age >= 36 * HOUR ? 0 : (stats[fields.days] || 0);
  const points = stats.total_points || 0;
  const used = stats.streakRestoreMonth === monthKey(now) ? stats.streakRestoresUsed || 0 : 0;
  const restoreDays = streak ? 0 : (stats[fields.days] || stats[fields.broken] || 0);
  const expiration = stats[fields.at] ? +new Date(stats[fields.at]) + 36 * HOUR : null;
  const recoveryEnd = expiration == null ? null : expiration + 24 * HOUR;
  const windowOpen = !streak && restoreDays > 0 && recoveryEnd != null && now >= expiration && now < recoveryEnd;
  return {
    total_points: points, streak_days: streak,
    streakRestoreLimit: RESTORES_PER_MONTH,
    streakRestoresRemaining: Math.max(0, RESTORES_PER_MONTH - used),
    recoverableStreakDays: restoreDays,
    canRestoreStreak: windowOpen && used < RESTORES_PER_MONTH,
    streakState: streak > 0 ? (age >= 24 * HOUR ? 'at_risk' : 'active') : windowOpen ? 'recoverable' : restoreDays > 0 ? 'expired' : 'empty',
    serverNow: new Date(now), serverDay: dayKey(now),
    expiresAt: expiration == null ? null : new Date(expiration),
    recoveryExpiresAt: recoveryEnd == null ? null : new Date(recoveryEnd),
    restoreWindowOpen: windowOpen,
    monthResetsAt: monthResetsAt(now),
    longestStreak: Math.max(stats[fields.longest] || 0, stats[fields.days] || 0, stats[fields.broken] || 0),
    activityCalendar: calendar(stats, now, fields),
    scoreEmoji: SCORE_EMOJIS.includes(stats.scoreEmoji) ? stats.scoreEmoji : '🔥',
    ringTier: points >= 100000 ? 'elite' : points >= 10000 ? 'orange' : 'basic',
    cosmeticVerified: points >= 200000,
    playedToday: source === 'game' ? stats.lastGameDay === dayKey(now) : stats.dailyGameDay === dayKey(now),
    state: streak === 0 ? 'inactive' : age >= 24 * HOUR ? 'ice_cold' : 'active',
    freezesAt: streak ? new Date(+new Date(stats[fields.at]) + 24 * HOUR) : null,
    resetsAt: streak ? new Date(+new Date(stats[fields.at]) + 36 * HOUR) : null,
    postedToday: source === 'story' ? stats[fields.day] === dayKey(now) : stats.lastStoryPointDay === dayKey(now),
    dailyLoveCount: stats.dailyLoveDay === dayKey(now) ? stats.dailyLoveCount || 0 : 0,
    ringUnlocked: points >= 10000, ringTarget: 10000, timeZone: TIME_ZONE,
  };
}
function postReward(stats, now) {
  expireStreak(stats, now);
  const today = dayKey(now);
  const before = progress(stats, now);
  // A new streak can start even on the same calendar day after an actual break.
  const increment = !before.streak_days || stats.lastPostDay !== today;
  stats.streak_days = before.streak_days + (increment ? 1 : 0);
  stats.longestStreak = Math.max(stats.longestStreak || 0, stats.streak_days);
  stats.activityDays = [...new Set([...(stats.activityDays || []), today])].sort().slice(-35);
  let points = stats.lastPostDay === today ? 0 : 100;
  if (increment && stats.streak_days % 7 === 0) points += 300;
  stats.total_points = (stats.total_points || 0) + points;
  stats.lastStoryAt = new Date(now);
  stats.lastPostDay = today;
  // Starting a fresh streak gives up restoration of the previous one.
  stats.brokenStreakDays = 0;
  return points;
}
// Community stories earn points for every eligible role, but only student
// stories advance the student's story-based activity streak.
function storyReward(stats, now) {
  const today = dayKey(now);
  if (stats.lastStoryPointDay === today) return 0;
  stats.lastStoryPointDay = today;
  stats.total_points = (stats.total_points || 0) + 100;
  return 100;
}
function storyPostReward(stats, now, role) {
  if (role === 'student') return postReward(stats, now);
  if (['parent', 'university', 'employee', 'admin'].includes(role)) return storyReward(stats, now);
  return 0;
}
function loveReward(stats, now) {
  const today = dayKey(now);
  if (stats.dailyLoveDay !== today) { stats.dailyLoveDay = today; stats.dailyLoveCount = 0; }
  const points = stats.dailyLoveCount < 10 ? 5 : 0;
  stats.dailyLoveCount = Math.min(10, stats.dailyLoveCount + 1);
  stats.total_points = (stats.total_points || 0) + points;
  return points;
}
function restoreStreak(stats, now, source = 'story') {
  const fields = fieldsFor(source);
  expireStreak(stats, now, source);
  const current = progress(stats, now, source);
  if (!current.recoverableStreakDays) throw Object.assign(new Error('لا يوجد ستريك منقطع لاسترجاعه.'), { statusCode: 409 });
  if (!current.restoreWindowOpen) throw Object.assign(new Error('انتهت مهلة الاسترجاع. يمكنك بدء سلسلة جديدة.'), { statusCode: 409, code: 'STREAK_WINDOW_EXPIRED' });
  if (!current.canRestoreStreak) throw Object.assign(new Error('استخدمت الاسترجاعات الثلاثة لهذا الشهر. يمكنك بدء ستريك جديد.'), { statusCode: 409 });
  const month = monthKey(now);
  stats.streakRestoresUsed = (stats.streakRestoreMonth === month ? stats.streakRestoresUsed || 0 : 0) + 1;
  stats.streakRestoreMonth = month;
  stats[fields.days] = current.recoverableStreakDays;
  stats[fields.longest] = Math.max(stats[fields.longest] || 0, stats[fields.days]);
  stats[fields.broken] = 0;
  stats[fields.at] = new Date(now);
  if (source === 'game') stats[fields.day] = dayKey(now);
  return progress(stats, now, source);
}
module.exports = { HOUR, TIME_ZONE, SCORE_EMOJIS, dayKey, monthKey, progress, postReward, storyReward, storyPostReward, loveReward, restoreStreak };
