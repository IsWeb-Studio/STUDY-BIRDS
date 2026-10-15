const { test } = require('node:test');
const assert = require('node:assert/strict');
const e = require('../src/games/winkEngine');
test('room capacity, settings validation, outsiders and client-controlled role are rejected', () => {
  const host = { id: 'host', name: 'Host' };
  const room = e.newRoom(host, 1000);
  for (let i = 1; i < 11; i++) e.join(room, { id: `player${i}`, name: `Player ${i}` }, 1000);
  assert.throws(() => e.join(room, { id: 'extra' }, 1000), (err) => err.gameCode === 'room-full');
  assert.throws(() => e.apply(room, { id: 'extra' }, 'start', {}, 1000), (err) => err.gameCode === 'not-member');
  assert.throws(() => e.apply(room, { id: 'player1' }, 'settings', room.settings, 1000), (err) => err.gameCode === 'host-lobby-only');
  assert.throws(() => e.apply(room, host, 'settings', { ...room.settings, cooldownSeconds: 0 }, 1000), (err) => err.gameCode === 'invalid-settings');
  assert.throws(() => e.apply(room, host, 'set-role', { role: 'winker' }, 1000), (err) => err.gameCode === 'not-alive');
  room.players.forEach((p) => { p.ready = true; });
  e.apply(room, host, 'settings', { mode: 'local', roundSeconds: 120, voteSeconds: 30, cooldownSeconds: 20 }, 1000);
  assert.ok(room.players.every((p) => !p.ready));
});
