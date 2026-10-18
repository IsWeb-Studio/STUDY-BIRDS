const { test } = require('node:test');
const assert = require('node:assert/strict');
const e = require('../src/games/winkEngine');
test('eleven-card deck deals 1–10 exactly once and eye 11 only to the winker', () => {
  const users = Array.from({ length: 11 }, (_, i) => ({ id: `p${i}`, name: `Player ${i}` }));
  const room = e.newRoom(users[0], 1000);
  for (const user of users.slice(1)) e.join(room, user, 1000);
  for (const user of users) e.apply(room, user, 'ready', { ready: true }, 1000);
  e.apply(room, users[0], 'start', {}, 1100, () => 7);
  assert.deepEqual(room.players.map((p) => p.card).sort((a, b) => a - b), Array.from({ length: 11 }, (_, i) => i + 1));
  assert.equal(room.players[7].card, 11);
  for (const user of users) {
    const view = e.view(room, user.id, 1100);
    assert.equal(view.me.card === 11, view.me.role === 'winker');
    assert.ok(view.players.every((p) => !Object.hasOwn(p, 'card')));
  }
});
test('smaller rooms receive distinct secret numbers, never a public seat-to-role mapping', () => {
  const users = Array.from({ length: 4 }, (_, i) => ({ id: `p${i}`, name: `Player ${i}` }));
  const room = e.newRoom(users[0], 1000);
  for (const user of users.slice(1)) e.join(room, user, 1000);
  for (const user of users) e.apply(room, user, 'ready', { ready: true }, 1000);
  e.apply(room, users[0], 'start', {}, 1100, () => 2);
  assert.equal(new Set(room.players.map((p) => p.card)).size, 4);
  assert.equal(e.view(room, 'p2', 1100).me.card, 11);
  for (const user of users) e.apply(room, user, 'seen', {}, 1200);
  e.apply(room, users[2], 'leave', {}, 1300);
  e.apply(room, users[0], 'reset', {}, 1400);
  assert.ok(room.players.every((p) => p.card == null));
  assert.equal(e.view(room, 'p0', 1400).me.card, null);
});
