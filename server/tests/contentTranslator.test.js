const { test } = require('node:test');
const assert = require('node:assert/strict');

test('translator only sends Arabic text to the model, caches results and degrades without config', async () => {
  const ContentTranslation = require('../src/models/ContentTranslation');
  const store = new Map();
  ContentTranslation.find = (query) => ({ lean: async () => [...store.values()].filter((row) => query.hash.$in.includes(row.hash) && row.target === query.target) });
  ContentTranslation.updateOne = async (key, update) => { store.set(`${key.hash}:${key.target}`, { hash: key.hash, target: key.target, text: update.$set.text }); };
  const { translateTexts } = require('../src/utils/contentTranslator');

  // Not configured: falls back to the keyless public endpoint; English passes through untouched.
  delete process.env.AI_API_KEY;
  const realFetch = global.fetch;
  const publicCalls = [];
  global.fetch = async (url, init) => { publicCalls.push(String(url)); return { ok: true, json: async () => [[['Public EN', 'src']]] }; };
  try {
    assert.deepEqual(await translateTexts(['مرحبا بكم', 'Already English'], 'en'), ['Public EN', 'Already English']);
    assert.equal(publicCalls.length, 1);
    assert.match(publicCalls[0], /translate.googleapis.com/);
  } finally { global.fetch = realFetch; }

  process.env.AI_API_KEY = 'k'; process.env.AI_MODEL = 'm'; process.env.AI_BASE_URL = 'https://ai.example.test/v1';
  const calls = [];
  global.fetch = async (url, init) => {
    const texts = JSON.parse(JSON.parse(init.body).messages[1].content);
    calls.push(texts);
    return { ok: true, json: async () => ({ choices: [{ message: { content: JSON.stringify(texts.map((t) => `EN(${t})`)) } }] }) };
  };
  try {
    const first = await translateTexts(['جامعة إسطنبول', 'Already English', 'جامعة إسطنبول'], 'en');
    assert.deepEqual(first, ['EN(جامعة إسطنبول)', 'Already English', 'EN(جامعة إسطنبول)']);
    assert.deepEqual(calls, [['جامعة إسطنبول']]);
    await translateTexts(['جامعة إسطنبول'], 'en');
    assert.equal(calls.length, 1, 'second request is served from the cache');
  } finally { global.fetch = realFetch; }
});
