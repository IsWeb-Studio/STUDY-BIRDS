const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { cacheRoute, clearResponseCache } = require('../src/utils/responseCache');

beforeEach(clearResponseCache);

function read(url = '/api/content/countries') {
  const headers = {};
  let queried = false;
  const res = {
    statusCode: 200,
    set(key, value) { headers[key] = value; return this; },
    get(key) { return headers[key]; },
    status(code) { this.statusCode = code; return this; },
    send(body) { this.body = body; return this; },
  };
  cacheRoute(60_000)({ method: 'GET', originalUrl: url }, res, () => { queried = true; });
  return { res, headers, get queried() { return queried; } };
}

test('public lists revalidate in browsers while repeated reads use the server cache', () => {
  const first = read();
  first.res.send('[{"name":"Country"}]');
  assert.equal(first.headers['Cache-Control'], 'public, max-age=0, must-revalidate');
  const second = read();
  assert.equal(second.queried, false);
  assert.equal(second.res.body, first.res.body);
  assert.equal(second.headers['X-Cache'], 'HIT');
  assert.equal(second.headers['Cache-Control'], first.headers['Cache-Control']);
});

test('a successful deletion invalidates all cached list variants and the next read omits the record', () => {
  for (const url of ['/api/content/countries', '/api/content/countries?page=2', '/api/programs']) read(url).res.send('[{"_id":"deleted"}]');
  clearResponseCache();
  for (const url of ['/api/content/countries', '/api/content/countries?page=2', '/api/programs']) {
    const next = read(url);
    assert.equal(next.queried, true);
    next.res.send('[]');
    assert.equal(read(url).res.body, '[]');
  }
});

test('a delayed pre-deletion read cannot put the deleted record back into the cache', () => {
  const oldRead = read();
  clearResponseCache();
  const freshRead = read();
  freshRead.res.send('[]');
  oldRead.res.send('[{"_id":"deleted"}]');
  assert.equal(read().res.body, '[]');
});
