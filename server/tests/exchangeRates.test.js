const { test } = require('node:test');
const assert = require('node:assert/strict');
const { getExchangeRates } = require('../src/controllers/exchangeRatesController');
test('rates are isolated by base and include SAR and identity conversion', async () => {
  const original = global.fetch;
  let calls = 0;
  global.fetch = async url => {
    calls++;
    const base = url.searchParams.get('base');
    return { ok: true, json: async () => url.searchParams.get('quotes').split(',').map(quote => ({
      base, quote, date: '2026-10-30', rate: base === 'SAR' ? 0.26667 : 3.75,
    })) };
  };
  async function request(base) {
    const res = { statusCode: 200, status(code) { this.statusCode = code; return this; }, json(data) { this.data = data; return this; } };
    await getExchangeRates({ query: { base } }, res);
    return res;
  }
  try {
    const sar = await request('SAR');
    assert.equal(sar.data.base, 'SAR'); assert.equal(sar.data.rates.SAR, 1);
    const usd = await request('USD');
    assert.equal(usd.data.base, 'USD'); assert.equal(usd.data.rates.USD, 1);
    assert.equal(usd.data.rates.SAR, 3.75);
    await request('SAR'); assert.equal(calls, 2);
    global.fetch = async () => { throw new Error('offline'); };
    assert.equal((await request('EGP')).statusCode, 502, 'must not reuse another base on failure');
    assert.equal((await request('invalid')).statusCode, 400);
  } finally { global.fetch = original; }
});
