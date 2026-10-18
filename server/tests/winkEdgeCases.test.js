const { test } = require('node:test');
const assert = require('node:assert/strict');
const e = require('../src/games/winkEngine');
const users = Array.from({ length: 5 }, (_, i) => ({ id: `p${i}`, name: `Player ${i}` }));
function play(count = 5) {
  const room = e.newRoom(users[0], 1000);
  for (const user of users.slice(1, count)) e.join(room, user, 1000);
  for (const user of users.slice(0, count)) e.apply(room, user, 'ready', { ready: true }, 1000);
  e.apply(room, users[0], 'start', {}, 1000, () => 0);
  for (const user of users.slice(0, count)) e.apply(room, user, 'seen', {}, 1100);
  return room;
}
test('invalid and spent accusations do not force pending victims out early', () => {
  const room = play();
  e.apply(room, users[1], 'got-wink', {}, 1200, () => 0);
  room.players[2].accused = true;
  assert.throws(() => e.apply(room, users[2], 'accuse', { target: 'p0' }, 1201), /cannot-accuse/);
  assert.throws(() => e.apply(room, users[3], 'accuse', { target: 'missing' }, 1201), /invalid-target/);
  assert.equal(room.players[1].eliminated, false);
  assert.equal(room.pending.length, 1);
});
test('the accused leaving cancels voting and resumes the surviving round', () => {
  const room = play();
  e.apply(room, users[1], 'accuse', { target: 'p2' }, 1200);
  e.apply(room, users[2], 'leave', {}, 1201);
  assert.equal(room.phase, 'playing'); assert.equal(room.vote, null);
  assert.equal(room.events.at(-1).type, 'vote-cancelled');
});
test('remaining completed ballots resolve when the final nonvoter leaves', () => {
  const room = play();
  e.apply(room, users[1], 'accuse', { target: 'p2' }, 1200);
  e.apply(room, users[0], 'vote', { choice: 'yes' }, 1201);
  e.apply(room, users[1], 'vote', { choice: 'yes' }, 1201);
  e.apply(room, users[3], 'vote', { choice: 'abstain' }, 1201);
  e.apply(room, users[4], 'leave', {}, 1202);
  assert.equal(room.phase, 'playing'); assert.equal(room.players[2].eliminated, true);
});
test('simultaneous accepted reports settle together without a round timeout', () => {
  const room = play(4);
  room.players.forEach((p) => { p.lastSeen = 5000; });
  room.pending = [{ id: 'p1', at: 5000 }, { id: 'p2', at: 5000 }];
  e.advance(room, 5000);
  assert.equal(room.winner, 'winker');
});
test('hosting transfers to a connected player before one still in reconnect grace', () => {
  const room = play();
  room.players[1].lastSeen = 0;
  room.players[2].lastSeen = 20000;
  e.apply(room, users[0], 'leave', {}, 20001);
  assert.equal(room.host, 'p2');
});
test('role reveal waits for players and migrates old reveal deadlines', () => {
  const room = e.newRoom(users[0], 1000);
  for (const user of users.slice(1, 4)) e.join(room, user, 1000);
  for (const user of users.slice(0, 4)) e.apply(room, user, 'ready', { ready: true }, 1000);
  e.apply(room, users[0], 'start', {}, 1000, () => 0);
  room.revealUntil = 61000;
  room.players.forEach((p) => { p.lastSeen = 3600000; });
  e.advance(room, 3600000);
  assert.equal(room.phase, 'reveal'); assert.equal(room.revealUntil, null);
  assert.ok(room.players.every((p) => p.card != null && p.ready && !p.seen));
});

test('voters can think for an hour, including rooms with old stored vote deadlines', () => {
  const room = play();
  e.apply(room, users[1], 'accuse', { target: 'p0' }, 1200);
  room.vote.endsAt = 21200;
  e.apply(room, users[1], 'vote', { choice: 'yes' }, 1300);
  room.players.forEach((p) => { p.lastSeen = 3600000; });
  e.advance(room, 3600000);
  assert.equal(room.phase, 'voting'); assert.equal(room.vote.endsAt, null);
  for (const index of [2, 3, 4]) e.apply(room, users[index], 'vote', { choice: 'yes' }, 3600001);
  assert.equal(room.winner, 'players');
});
test('a stale ballot cannot be applied to another accusation in the same round', () => {
  const room = play();
  e.apply(room, users[1], 'accuse', { target: 'p2' }, 1200);
  const oldId = room.vote.id;
  for (const index of [0, 1, 3, 4]) e.apply(room, users[index], 'vote', { choice: 'no' }, 1201);
  e.apply(room, users[3], 'accuse', { target: 'p4' }, 1202);
  assert.notEqual(room.vote.id, oldId);
  assert.throws(() => e.apply(room, users[1], 'vote', { choice: 'yes', voteId: oldId }, 1203), /stale-vote/);
  assert.equal(room.vote.ballots.p1, undefined);
});
