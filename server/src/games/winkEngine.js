const { randomInt, randomBytes } = require('node:crypto');

const fail = (code) => { const error = new Error(code); error.gameCode = code; throw error; };
const alive = (room) => room.players.filter((p) => !p.left && !p.eliminated);
const event = (room, type, now, player = null) => {
  room.events.push({ type, at: now, player });
  room.events = room.events.slice(-40);
};
function finish(room, winner, reason, now) {
  room.phase = 'finished'; room.winner = winner; room.reason = reason;
  room.pending = []; room.vote = null; event(room, 'finished', now);
}
function checkWin(room, now) {
  if (!['playing', 'voting'].includes(room.phase)) return;
  const living = alive(room);
  if (!living.some((p) => p.id === room.winker)) finish(room, 'players', 'winker-out', now);
  else if (living.length <= 2) finish(room, 'winker', 'last-two', now);
  else if (now >= room.endsAt) finish(room, 'players', 'time', now);
}
function eliminate(room, id, now, type = 'eliminated') {
  const player = room.players.find((p) => p.id === id);
  if (!player || player.eliminated || player.left) return;
  player.eliminated = true; player.privateNotice = null;
  event(room, type, now, id); checkWin(room, now);
}
function settlePending(room, now, all = false) {
  const pending = room.pending;
  room.pending = pending.filter((item) => !all && item.at > now);
  for (const item of pending) {
    if ((all || item.at <= now) && ['playing', 'voting'].includes(room.phase)) eliminate(room, item.id, now);
  }
}
function leave(room, player, now) {
  player.left = true; player.privateNotice = null;
  room.pending = room.pending.filter((item) => item.id !== player.id);
  event(room, 'left', now, player.id);
  if (room.host === player.id) {
    room.host = room.players.find((p) => !p.left && now - p.lastSeen < 60000)?.id
      || room.players.find((p) => !p.left)?.id || null;
  }
  if (room.phase === 'reveal') reset(room, now);
  checkWin(room, now);
  if (!room.players.some((p) => !p.left)) room.phase = 'closed';
}
function resolveVote(room, now) {
  if (room.phase !== 'voting') return;
  const vote = room.vote;
  const voters = alive(room).filter((p) => p.id !== vote.accused);
  const yes = voters.filter((p) => vote.ballots[p.id] === 'yes').length;
  room.vote = null; room.phase = 'playing';
  event(room, yes > voters.length / 2 ? 'vote-approved' : 'vote-rejected', now, vote.accused);
  if (yes > voters.length / 2) eliminate(room, vote.accused, now, 'accused-out');
  checkWin(room, now);
}
function reset(room, now) {
  room.phase = 'lobby'; room.winker = null; room.pending = []; room.vote = null;
  room.endsAt = null; room.revealUntil = null; room.nextWinkAt = 0;
  room.winner = null; room.reason = null; room.events = [];
  room.players = room.players.filter((p) => !p.left).map((p) => ({
    ...p, eliminated: false, ready: false, seen: false, accused: false, privateNotice: null,
  }));
  event(room, 'lobby', now);
}
function advance(room, now) {
  if (room.phase === 'closed') return;
  // Resolve overdue events in their actual order, including after a restart.
  // A wink due AFTER the round deadline must not change the winner.
  const due = room.players.filter((p) => !p.left).map((p) => ({ at: p.lastSeen + 60000, type: 'disconnect', id: p.id }));
  if (room.phase === 'reveal') due.push({ at: room.revealUntil, type: 'reveal' });
  if (['playing', 'voting'].includes(room.phase)) {
    for (const item of room.pending) due.push({ at: item.at, type: 'wink' });
    if (room.vote) due.push({ at: room.vote.endsAt, type: 'vote' });
    due.push({ at: room.endsAt, type: 'end' });
  }
  for (const item of due.filter((item) => item.at <= now).sort((a, b) => a.at - b.at)) {
    if (room.phase === 'closed') break;
    if (item.type === 'disconnect') {
      const player = room.players.find((p) => p.id === item.id && !p.left);
      if (player) leave(room, player, item.at);
    } else if (item.type === 'reveal' && room.phase === 'reveal') {
      reset(room, item.at); event(room, 'reveal-timeout', item.at);
    } else if (item.type === 'wink' && room.phase === 'playing') settlePending(room, item.at);
    else if (item.type === 'vote' && room.phase === 'voting') resolveVote(room, item.at);
    else if (item.type === 'end') checkWin(room, item.at);
  }
  checkWin(room, now);
}
function newRoom(user, now = Date.now()) {
  const room = { phase: 'lobby', host: user.id, players: [],
    settings: { mode: 'online', roundSeconds: 300, voteSeconds: 20, cooldownSeconds: 15 },
    round: 0, pending: [], events: [], receipts: [], winker: null, vote: null,
    endsAt: null, nextWinkAt: 0, winner: null, reason: null };
  join(room, user, now); return room;
}
function join(room, user, now) {
  const existing = room.players.find((p) => p.id === user.id && !p.left);
  if (existing) { existing.lastSeen = now; return; }
  if (room.phase !== 'lobby') fail('already-started');
  if (room.players.filter((p) => !p.left).length >= 12) fail('room-full');
  room.players = room.players.filter((p) => p.id !== user.id && !p.left);
  room.players.push({ id: user.id, name: user.name, avatar: user.avatar || null,
    ready: false, seen: false, eliminated: false, accused: false, left: false, lastSeen: now });
}
function apply(room, user, action, payload = {}, now = Date.now(), choose = randomInt) {
  advance(room, now);
  const player = room.players.find((p) => p.id === user.id && !p.left);
  if (!player) fail('not-member');
  player.lastSeen = now;
  if (action === 'heartbeat') return;
  if (action === 'leave') { leave(room, player, now); return; }
  if (action === 'settings') {
    if (room.host !== user.id || room.phase !== 'lobby') fail('host-lobby-only');
    if (!['online', 'local'].includes(payload.mode) || !Number.isInteger(payload.roundSeconds)
      || payload.roundSeconds < 60 || payload.roundSeconds > 900 || !Number.isInteger(payload.voteSeconds)
      || payload.voteSeconds < 10 || payload.voteSeconds > 60 || !Number.isInteger(payload.cooldownSeconds)
      || payload.cooldownSeconds < 5 || payload.cooldownSeconds > 60) fail('invalid-settings');
    room.settings = { mode: payload.mode, roundSeconds: payload.roundSeconds,
      voteSeconds: payload.voteSeconds, cooldownSeconds: payload.cooldownSeconds };
    for (const p of room.players) p.ready = false;
    return;
  }
  if (action === 'ready') {
    if (room.phase !== 'lobby' || typeof payload.ready !== 'boolean') fail('lobby-only');
    player.ready = payload.ready; return;
  }
  if (action === 'reset') {
    if (room.host !== user.id || room.phase !== 'finished') fail('host-finished-only');
    reset(room, now); return;
  }
  if (action === 'start') {
    if (room.host !== user.id || room.phase !== 'lobby') fail('host-lobby-only');
    const members = room.players.filter((p) => !p.left);
    if (members.length < 4 || members.some((p) => !p.ready || now - p.lastSeen > 10000)) fail('not-ready');
    room.round++; room.winker = members[choose(members.length)].id;
    room.phase = 'reveal'; room.revealUntil = now + 60000;
    room.pending = []; room.vote = null; room.events = []; room.winner = null; room.reason = null;
    for (const p of members) { p.seen = false; p.eliminated = false; p.accused = false; p.privateNotice = null; }
    return;
  }
  if (action === 'seen') {
    if (room.phase !== 'reveal') fail('reveal-only');
    player.seen = true;
    if (room.players.filter((p) => !p.left).every((p) => p.seen)) {
      room.phase = 'playing'; room.endsAt = now + room.settings.roundSeconds * 1000;
      room.nextWinkAt = now; event(room, 'started', now);
    }
    return;
  }
  if (!['playing', 'voting'].includes(room.phase) || player.eliminated) fail('not-alive');
  if (action === 'wink' || action === 'got-wink') {
    if (room.phase !== 'playing') fail('vote-active');
    if (action === 'wink') {
      if (room.settings.mode !== 'online' || room.winker !== player.id) fail('not-winker');
      if (now < room.nextWinkAt) fail('cooldown');
    } else if (room.settings.mode !== 'local' || room.winker === player.id) fail('local-only');
    const target = action === 'got-wink' ? player : alive(room).find((p) => p.id === payload.target);
    if (!target || target.id === room.winker || room.pending.some((p) => p.id === target.id)) fail('invalid-target');
    room.pending.push({ id: target.id, at: now + 3000 + choose(4001) });
    target.privateNotice = 'winked';
    if (action === 'wink') room.nextWinkAt = now + room.settings.cooldownSeconds * 1000;
    return;
  }
  if (action === 'accuse') {
    if (room.phase !== 'playing') fail('vote-active');
    // Flush accepted winks before determining who is eligible for a vote.
    settlePending(room, now, true);
    if (room.phase !== 'playing' || player.eliminated || player.accused) fail('cannot-accuse');
    if (payload.target === player.id || !alive(room).some((p) => p.id === payload.target)) fail('invalid-target');
    player.accused = true; room.phase = 'voting';
    room.vote = { accused: payload.target, by: player.id, endsAt: now + room.settings.voteSeconds * 1000, ballots: {} };
    event(room, 'vote-started', now, payload.target); return;
  }
  if (action === 'vote') {
    if (room.phase !== 'voting' || room.vote.accused === player.id) fail('cannot-vote');
    if (!['yes', 'no', 'abstain'].includes(payload.choice)) fail('invalid-vote');
    if (room.vote.ballots[player.id]) fail('already-voted');
    room.vote.ballots[player.id] = payload.choice;
    if (alive(room).filter((p) => p.id !== room.vote.accused).every((p) => room.vote.ballots[p.id])) resolveVote(room, now);
    return;
  }
  fail('invalid-action');
}
// Explicit allowlist: never serialize the stored room, ballots or pending victims.
function view(room, id, now = Date.now()) {
  const self = room.players.find((p) => p.id === id && !p.left);
  if (!self) fail('not-member');
  return { phase: room.phase, host: room.host, settings: room.settings, round: room.round,
    serverNow: now, endsAt: room.endsAt, revealUntil: room.revealUntil,
    players: room.players.map((p) => ({ id: p.id, name: p.name, avatar: p.avatar,
      ready: p.ready, seen: p.seen, eliminated: p.eliminated, left: p.left,
      connected: !p.left && now - p.lastSeen < 10000,
      reconnectUntil: p.lastSeen + 60000 })),
    events: room.events, vote: room.vote ? { accused: room.vote.accused, by: room.vote.by,
      endsAt: room.vote.endsAt, count: Object.keys(room.vote.ballots).length } : null,
    me: { id, role: ['reveal', 'playing', 'voting', 'finished'].includes(room.phase)
      ? (room.winker === id ? 'winker' : 'player') : null,
      seen: self.seen, accused: self.accused, eliminated: self.eliminated,
      notice: self.privateNotice || null,
      nextWinkAt: room.winker === id ? room.nextWinkAt : null,
      ballot: room.vote?.ballots[id] || null },
    result: room.phase === 'finished' ? { winner: room.winner, winker: room.winker, reason: room.reason } : null };
}
module.exports = { newRoom, join, apply, advance, view, code: () => randomBytes(4).toString('hex').toUpperCase(), fail };
