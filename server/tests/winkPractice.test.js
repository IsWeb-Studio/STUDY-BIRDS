const { test } = require('node:test');
const assert = require('node:assert/strict');
const e = require('../src/games/winkEngine');
const practice = require('../src/games/winkPractice');
const user = { id: 'human', name: 'Human' };
function play(role = 'player') {
  const room = practice.create(user, role, 1000);
  practice.apply(room, user, 'seen', {}, 2000);
  practice.advance(room, 2000, () => 1);
  return room;
}
test('one human and exactly three bots enter reveal without other accounts', () => {
  const room = practice.create(user, 'player', 1000);
  assert.equal(room.phase, 'reveal'); assert.equal(room.players.length, 4);
  assert.equal(room.players.filter((p) => p.bot).length, 3);
  assert.ok(room.players.filter((p) => p.bot).every((p) => p.ready && p.seen));
  assert.equal(room.players[0].seen, false);
  const view = e.view(room, user.id, 1000);
  assert.equal(view.isPractice, true); assert.equal(view.me.role, 'player');
  assert.ok(view.players.every((p) => !Object.hasOwn(p, 'role') && !Object.hasOwn(p, 'card')));
  assert.equal(view.practice, undefined);
});
test('bot winker reports bot victims and bots cast automatic ballots', () => {
  const room = play();
  practice.advance(room, 16000, () => 1);
  assert.equal(room.pending.length, 1);
  assert.notEqual(room.pending[0].id, user.id);
  practice.advance(room, 24000, () => 1);
  assert.equal(room.players.filter((p) => p.eliminated).length, 1);
  practice.apply(room, user, 'accuse', { target: room.winker }, 24001);
  practice.advance(room, 24001, () => 1);
  assert.equal(room.phase, 'voting');
  practice.apply(room, user, 'vote', { choice: 'yes', voteId: room.vote.id }, 24002);
  practice.advance(room, 29000, () => 1);
  assert.equal(room.phase, 'finished'); assert.equal(room.winner, 'players');
});
test('human winker can wink without a cooldown, wins against bots and restarts as player', () => {
  const room = play('winker');
  const bots = room.players.filter((p) => p.bot);
  practice.apply(room, user, 'practice-wink', { target: bots[0].id }, 3000);
  practice.apply(room, user, 'practice-wink', { target: bots[1].id }, 3001);
  assert.equal(room.pending.length, 2);
  assert.equal(room.nextWinkAt, 0);
  practice.advance(room, 11000, () => 1);
  assert.equal(bots[0].eliminated, true);
  assert.equal(room.phase, 'finished'); assert.equal(room.winner, 'winker');
  practice.apply(room, user, 'practice-restart', { role: 'player' }, 27000);
  practice.advance(room, 27000, () => 1);
  assert.equal(room.phase, 'reveal'); assert.notEqual(room.winker, user.id);
  assert.equal(room.pending.length, 0); assert.equal(room.vote, null);
  assert.ok(room.players.every((p) => !p.eliminated && !p.accused));
});
test('training actions cannot change real rooms; owner expiry closes the bots room', () => {
  const real = e.newRoom(user, 1000);
  assert.throws(() => practice.apply(real, user, 'practice-wink', { target: 'other' }, 1001), /practice-only/);
  assert.throws(() => practice.apply(real, user, 'practice-restart', { role: 'winker' }, 1001), /practice-only/);
  const room = play();
  practice.advance(room, 62001, () => 1);
  assert.equal(room.phase, 'closed');
});
