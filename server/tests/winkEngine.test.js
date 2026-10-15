const { test } = require('node:test');
const assert = require('node:assert/strict');
const e = require('../src/games/winkEngine');
const users = Array.from({ length: 5 }, (_, i) => ({ id: `p${i}`, name: `Player ${i}` }));
function setup(count = 4, mode = 'local') {
  const room = e.newRoom(users[0], 1000);
  for (const user of users.slice(1, count)) e.join(room, user, 1000);
  room.settings.mode = mode;
  for (const user of users.slice(0, count)) e.apply(room, user, 'ready', { ready: true }, 1000);
  e.apply(room, users[0], 'start', {}, 1000, () => 0);
  return room;
}
function play(count = 4, mode = 'local') {
  const room = setup(count, mode);
  for (const user of users.slice(0, count)) e.apply(room, user, 'seen', {}, 1100);
  return room;
}
const throws = (fn, code) => assert.throws(fn, (error) => error.gameCode === code);

test('minimum, readiness, host authority, and all role confirmations required', () => {
  const room = e.newRoom(users[0], 1000);
  throws(() => e.apply(room, users[0], 'start', {}, 1000), 'not-ready');
  const reveal = setup();
  throws(() => e.apply(reveal, users[1], 'start', {}, 1000), 'host-lobby-only');
  e.apply(reveal, users[0], 'seen', {}, 1100);
  assert.equal(reveal.phase, 'reveal');
  throws(() => e.join(reveal, users[4], 1100), 'already-started');
  e.advance(reveal, 61001);
  assert.ok(['lobby', 'closed'].includes(reveal.phase));
});
test('exactly one role and explicit public projection excludes secrets', () => {
  const room = play();
  assert.equal(users.slice(0, 4).filter((u) => e.view(room, u.id, 1100).me.role === 'winker').length, 1);
  e.apply(room, users[1], 'got-wink', {}, 1200, () => 0);
  const bystander = e.view(room, 'p2', 1200);
  for (const key of ['winker', 'pending', 'receipts', 'nextWinkAt']) assert.equal(bystander[key], undefined);
  assert.equal(bystander.players.find((p) => p.id === 'p1').privateNotice, undefined);
  assert.equal(bystander.result, null);
  assert.equal(e.view(room, 'p1', 1200).me.notice, 'winked');
  assert.equal(e.view(room, 'p0', 1200).me.notice, null);
  throws(() => e.view(room, 'outsider', 1200), 'not-member');
});
test('random selection receives player count, wins after delayed reports and rejects duplicate reports', () => {
  const room = play();
  throws(() => e.apply(room, users[1], 'wink', { target: 'p2' }, 1200), 'digital-wink-disabled');
  e.apply(room, users[1], 'got-wink', {}, 1200, () => 0);
  throws(() => e.apply(room, users[1], 'got-wink', {}, 1201), 'invalid-target');
  e.advance(room, 4199); assert.equal(room.players[1].eliminated, false);
  e.advance(room, 4200); assert.equal(room.players[1].eliminated, true);
  throws(() => e.apply(room, users[1], 'accuse', { target: 'p0' }, 4201), 'not-alive');
  e.apply(room, users[2], 'got-wink', {}, 16200, () => 0);
  e.advance(room, 19200);
  assert.equal(room.winner, 'winker'); assert.equal(room.phase, 'finished');
});
test('a strict majority is required; abstention and silence never approve', () => {
  const room = play(5);
  e.apply(room, users[1], 'accuse', { target: 'p2' }, 1200);
  throws(() => e.apply(room, users[3], 'got-wink', {}, 1201), 'vote-active');
  throws(() => e.apply(room, users[2], 'vote', { choice: 'yes' }, 1201), 'cannot-vote');
  throws(() => e.apply(room, users[3], 'accuse', { target: 'p0' }, 1201), 'vote-active');
  e.apply(room, users[0], 'vote', { choice: 'yes' }, 1202);
  throws(() => e.apply(room, users[0], 'vote', { choice: 'yes' }, 1203), 'already-voted');
  e.apply(room, users[1], 'vote', { choice: 'yes' }, 1202);
  e.apply(room, users[3], 'vote', { choice: 'abstain' }, 1202);
  e.advance(room, 21200);
  assert.equal(room.players[2].eliminated, false); assert.equal(room.phase, 'playing');
  throws(() => e.apply(room, users[1], 'accuse', { target: 'p0' }, 21201), 'cannot-accuse');
});
test('approved guilty suspect ends round and reset clears all round state', () => {
  const room = play();
  e.apply(room, users[1], 'accuse', { target: 'p0' }, 1200);
  for (const user of users.slice(1, 4)) e.apply(room, user, 'vote', { choice: 'yes' }, 1201);
  assert.equal(room.winner, 'players');
  assert.equal(e.view(room, 'p1', 1202).result.winker, 'p0');
  e.apply(room, users[0], 'reset', {}, 1300);
  assert.equal(room.winker, null); assert.equal(room.vote, null); assert.deepEqual(room.pending, []);
  assert.ok(room.players.every((p) => !p.eliminated && !p.accused && !p.ready && !p.seen && !p.privateNotice));
  for (const user of users.slice(0, 4)) e.apply(room, user, 'ready', { ready: true }, 1400);
  e.apply(room, users[0], 'start', {}, 1401, (max) => { assert.equal(max, 4); return 2; });
  assert.equal(room.winker, 'p2'); assert.equal(room.round, 2);
});
test('innocent elimination continues and pending wink is settled before accusation', () => {
  const room = play(5);
  e.apply(room, users[1], 'got-wink', {}, 1200, () => 0);
  throws(() => e.apply(room, users[1], 'accuse', { target: 'p0' }, 1201), 'cannot-accuse');
  assert.equal(room.players[1].eliminated, true);
  e.apply(room, users[2], 'accuse', { target: 'p3' }, 1202);
  for (const index of [0, 2, 4]) e.apply(room, users[index], 'vote', { choice: 'yes' }, 1203);
  assert.equal(room.players[3].eliminated, true); assert.equal(room.phase, 'playing');
});
test('face-to-face mode accepts self-report only and rejects digital winks', () => {
  const room = play(4, 'local');
  throws(() => e.apply(room, users[0], 'wink', { target: 'p1' }, 1200), 'digital-wink-disabled');
  throws(() => e.apply(room, users[0], 'got-wink', {}, 1200), 'local-only');
  e.apply(room, users[1], 'got-wink', {}, 1200, () => 0);
  assert.equal(room.pending[0].id, 'p1');
  throws(() => e.apply(room, users[1], 'got-wink', {}, 1201), 'invalid-target');
});
test('disconnect and reconnect preserve round; timeout, host transfer, and empty close', () => {
  const room = play(); const endsAt = room.endsAt;
  e.apply(room, users[0], 'heartbeat', {}, 50000);
  assert.equal(room.endsAt, endsAt); assert.equal(room.players[0].left, false);
  for (const user of users.slice(1, 4)) e.apply(room, user, 'heartbeat', {}, 60000);
  e.advance(room, 110001);
  assert.equal(room.players[0].left, true); assert.equal(room.winner, 'players');
  assert.equal(room.host, 'p1');
  e.advance(room, 180000); assert.equal(room.phase, 'closed');
});
test('explicit winker exit wins for players, normal exit rechecks last two, timer wins for players', () => {
  const room = play(); e.apply(room, users[0], 'leave', {}, 1200);
  assert.equal(room.winner, 'players'); assert.equal(room.host, 'p1');
  const ordinary = play(); e.apply(ordinary, users[1], 'leave', {}, 1200); e.apply(ordinary, users[2], 'leave', {}, 1200);
  assert.equal(ordinary.winner, 'winker');
  const timed = play(); timed.players.forEach((p) => { p.lastSeen = timed.endsAt; });
  e.advance(timed, timed.endsAt); assert.equal(timed.winner, 'players');
});
test('server restart resolves round expiry before a later pending elimination', () => {
  const room = play();
  room.players[1].eliminated = true;
  room.players.forEach((p) => { p.lastSeen = room.endsAt; });
  room.pending = [{ id: 'p2', at: room.endsAt + 1000 }];
  e.advance(room, room.endsAt + 2000);
  assert.equal(room.winner, 'players');
  assert.equal(room.players[2].eliminated, false);
});
