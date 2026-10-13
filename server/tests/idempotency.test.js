const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createIdempotency } = require('../src/middleware/idempotency');

// In-memory store with the same contract as the Mongo one.
function memoryStore({ failBegin = false } = {}) {
  const rows = new Map();
  return {
    rows,
    async begin(scope, key, fingerprint) {
      if (failBegin) throw new Error('db down');
      const id = `${scope}:${key}`;
      const row = rows.get(id);
      if (!row) { rows.set(id, { fingerprint, state: 'in_progress' }); return { state: 'new' }; }
      if (row.fingerprint !== fingerprint) return { state: 'mismatch' };
      if (row.state === 'done') return { state: 'done', record: row };
      return { state: 'in_progress' };
    },
    async complete(scope, key, status, body) { Object.assign(rows.get(`${scope}:${key}`), { state: 'done', status, body }); },
    async release(scope, key) { rows.delete(`${scope}:${key}`); },
  };
}

async function start(store, handlerDelayMs = 0) {
  const app = express();
  app.use(express.json());
  app.use('/api', createIdempotency(store));
  let runs = 0;
  app.post('/api/orders', async (req, res) => {
    runs += 1;
    if (handlerDelayMs) await new Promise((r) => setTimeout(r, handlerDelayMs));
    if (req.body.fail) return res.status(500).json({ message: 'boom' });
    if (req.body.bad) return res.status(400).json({ message: 'bad input' });
    res.status(201).json({ id: `order-${runs}`, amount: req.body.amount });
  });
  app.post('/api/auth/login', (req, res) => { runs += 1; res.json({ token: `t${runs}` }); });
  const server = await new Promise((resolve) => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (path, body, headers = {}) => fetch(base + path, {
    method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body),
  });
  return { post, runsNow: () => runs, close: () => new Promise((r) => { server.closeAllConnections?.(); server.close(r); }) };
}

const settle = () => new Promise((r) => setTimeout(r, 30)); // 'finish' stores asynchronously

test('a retried write with the same key runs once and replays the answer', async () => {
  const api = await start(memoryStore());
  try {
    const first = await api.post('/api/orders', { amount: 5 }, { 'Idempotency-Key': 'key-0001-aaaa' });
    assert.equal(first.status, 201);
    const a = await first.json();
    await settle();
    const second = await api.post('/api/orders', { amount: 5 }, { 'Idempotency-Key': 'key-0001-aaaa' });
    assert.equal(second.status, 201);
    assert.equal(second.headers.get('idempotent-replay'), 'true');
    assert.deepEqual(await second.json(), a);
    assert.equal(api.runsNow(), 1, 'handler must not run twice (no duplicate payment/booking)');
  } finally { await api.close(); }
});

test('concurrent duplicates: one runs, the other gets 409', async () => {
  const api = await start(memoryStore(), 120);
  try {
    const headers = { 'Idempotency-Key': 'key-0002-bbbb' };
    const [x, y] = await Promise.all([
      api.post('/api/orders', { amount: 1 }, headers),
      api.post('/api/orders', { amount: 1 }, headers),
    ]);
    assert.deepEqual([x.status, y.status].sort(), [201, 409]);
    assert.equal(api.runsNow(), 1);
  } finally { await api.close(); }
});

test('same key with a different body is rejected (422)', async () => {
  const api = await start(memoryStore());
  try {
    await api.post('/api/orders', { amount: 1 }, { 'Idempotency-Key': 'key-0003-cccc' });
    await settle();
    const res = await api.post('/api/orders', { amount: 999 }, { 'Idempotency-Key': 'key-0003-cccc' });
    assert.equal(res.status, 422);
    assert.equal(api.runsNow(), 1);
  } finally { await api.close(); }
});

test('5xx answers are not stored, so the same key can be retried', async () => {
  const api = await start(memoryStore());
  try {
    const h = { 'Idempotency-Key': 'key-0004-dddd' };
    assert.equal((await api.post('/api/orders', { fail: true }, h)).status, 500);
    await settle();
    assert.equal((await api.post('/api/orders', { fail: true }, h)).status, 500);
    assert.equal(api.runsNow(), 2, 'the handler ran again; nothing was replayed from cache');
  } finally { await api.close(); }
});

test('4xx answers are stored and replayed (a bad request stays bad)', async () => {
  const api = await start(memoryStore());
  try {
    const h = { 'Idempotency-Key': 'key-0005-eeee' };
    assert.equal((await api.post('/api/orders', { bad: true }, h)).status, 400);
    await settle();
    const again = await api.post('/api/orders', { bad: true }, h);
    assert.equal(again.status, 400);
    assert.equal(api.runsNow(), 1);
  } finally { await api.close(); }
});

test('different callers never share keys', async () => {
  const api = await start(memoryStore());
  try {
    const key = { 'Idempotency-Key': 'key-0006-ffff' };
    await api.post('/api/orders', { amount: 1 }, { ...key, Authorization: 'Bearer user-A' });
    await settle();
    const other = await api.post('/api/orders', { amount: 1 }, { ...key, Authorization: 'Bearer user-B' });
    assert.equal(other.status, 201);
    assert.equal(other.headers.get('idempotent-replay'), null);
    assert.equal(api.runsNow(), 2);
  } finally { await api.close(); }
});

test('credentials endpoints are never cached or replayed', async () => {
  const api = await start(memoryStore());
  try {
    const h = { 'Idempotency-Key': 'key-0007-gggg' };
    const a = await (await api.post('/api/auth/login', {}, h)).json();
    const b = await (await api.post('/api/auth/login', {}, h)).json();
    assert.notEqual(a.token, b.token);
  } finally { await api.close(); }
});

test('requests without a key behave as before; malformed keys are rejected', async () => {
  const api = await start(memoryStore());
  try {
    assert.equal((await api.post('/api/orders', { amount: 1 })).status, 201);
    assert.equal((await api.post('/api/orders', { amount: 1 })).status, 201);
    assert.equal(api.runsNow(), 2);
    assert.equal((await api.post('/api/orders', {}, { 'Idempotency-Key': 'x' })).status, 400);
  } finally { await api.close(); }
});

test('if the store is down the API still works (fail open)', async () => {
  const api = await start(memoryStore({ failBegin: true }));
  try {
    const res = await api.post('/api/orders', { amount: 1 }, { 'Idempotency-Key': 'key-0008-hhhh' });
    assert.equal(res.status, 201);
  } finally { await api.close(); }
});
