const { randomInt } = require('node:crypto');
const engine = require('./winkEngine');
const living = (room) => room.players.filter((p) => !p.left && !p.eliminated);

function deal(room, now) {
  const owner = room.players.find((p) => p.id === room.practice.owner);
  for (const p of room.players) {
    p.lastSeen = now;
    engine.apply(room, p, 'ready', { ready: true }, now);
  }
  const bots = room.players.filter((p) => p.bot);
  const chosen = room.practice.role === 'winker' ? room.players.indexOf(owner)
    : room.players.indexOf(bots[randomInt(bots.length)]);
  // Choosing a role is intentionally confined to this private training room.
  engine.apply(room, owner, 'start', {}, now, () => chosen);
  room.practice.winkAt = now + 14000;
  room.practice.accuseAt = now + 30000;
  room.practice.voteId = null;
  room.practice.voteTimes = {};
  room.practice.wasPlaying = false;
}

function create(user, role = 'player', now = Date.now()) {
  if (!['player', 'winker'].includes(role)) engine.fail('invalid-practice-role');
  const room = engine.newRoom(user, now);
  for (let i = 1; i <= 3; i++) {
    engine.join(room, { id: `practice-bot-${i}`, name: ['آدم', 'نور', 'عمر'][i - 1] }, now);
    room.players.at(-1).bot = true;
  }
  room.practice = { owner: user.id, role };
  deal(room, now);
  advance(room, now);
  return room;
}

function apply(room, user, action, payload, now = Date.now()) {
  if (room.practice && action === 'start' && room.phase === 'lobby') {
    if (room.practice.owner !== user.id) engine.fail('practice-only');
    deal(room, now); return;
  }
  if (action === 'practice-restart') {
    if (!room.practice || room.practice.owner !== user.id) engine.fail('practice-only');
    if (room.phase !== 'finished' || !['player', 'winker'].includes(payload.role)) engine.fail('host-finished-only');
    engine.apply(room, user, 'reset', {}, now);
    room.practice.role = payload.role;
    deal(room, now);
    return;
  }
  if (action === 'practice-wink') {
    if (!room.practice || room.practice.owner !== user.id) engine.fail('practice-only');
    if (room.phase !== 'playing' || room.winker !== user.id || !living(room).some((p) => p.id === user.id)) engine.fail('not-winker');
    if (now < room.nextWinkAt) engine.fail('cooldown');
    const victim = living(room).find((p) => p.id === payload.target && p.bot);
    if (!victim) engine.fail('invalid-target');
    engine.apply(room, victim, 'got-wink', {}, now);
    room.nextWinkAt = now + 15000;
    return;
  }
  engine.apply(room, user, action, payload, now);
}

function advance(room, now = Date.now(), choose = randomInt) {
  if (!room.practice) { engine.advance(room, now); return; }
  if (room.phase === 'closed') return;
  // Bots have no device/presence deadline. The human still has the usual grace.
  for (const p of room.players.filter((p) => p.bot && !p.left)) p.lastSeen = now;
  engine.advance(room, now);
  const owner = room.players.find((p) => p.id === room.practice.owner && !p.left);
  if (!owner) { room.phase = 'closed'; room.pending = []; room.vote = null; return; }
  if (room.phase === 'lobby') {
    for (const bot of room.players.filter((p) => p.bot)) bot.ready = true;
  }
  if (room.phase === 'reveal') {
    for (const bot of room.players.filter((p) => p.bot && !p.seen)) engine.apply(room, bot, 'seen', {}, now);
    return;
  }
  if (room.phase === 'voting') {
    if (room.practice.voteId !== room.vote.id) {
      room.practice.voteId = room.vote.id;
      room.practice.voteTimes = Object.fromEntries(living(room).filter((p) => p.bot).map((p) => [p.id, now + 1500 + choose(2501)]));
    }
    for (const bot of living(room).filter((p) => p.bot)) {
      if (room.phase !== 'voting') break;
      if (bot.id === room.vote.accused || room.vote.ballots[bot.id] || now < room.practice.voteTimes[bot.id]) continue;
      const choice = bot.id === room.winker ? 'no' : choose(4) === 0 ? 'abstain' : 'yes';
      engine.apply(room, bot, 'vote', { choice, voteId: room.vote.id }, now);
    }
    return;
  }
  if (room.phase !== 'playing') return;
  if (!room.practice.wasPlaying) {
    room.practice.wasPlaying = true;
    room.practice.winkAt = now + 14000;
    room.practice.accuseAt = now + 30000;
  }
  if (now >= room.practice.winkAt && room.winker !== owner.id) {
    const targets = living(room).filter((p) => p.id !== room.winker && !room.pending.some((item) => item.id === p.id));
    // The first victim is another bot, giving the human time to learn the UI.
    const target = targets.find((p) => p.bot) || targets[0];
    if (target) engine.apply(room, target, 'got-wink', {}, now);
    room.practice.winkAt = now + 20000;
  }
  if (room.phase === 'playing' && room.pending.length === 0 && now >= room.practice.accuseAt) {
    const bot = living(room).find((p) => p.bot && !p.accused && !room.pending.some((item) => item.id === p.id));
    const targets = living(room).filter((p) => p.id !== bot?.id && !room.pending.some((item) => item.id === p.id));
    if (bot && targets.length) engine.apply(room, bot, 'accuse', { target: targets[choose(targets.length)].id }, now);
    room.practice.accuseAt = now + 30000;
  }
}

module.exports = { create, apply, advance };
