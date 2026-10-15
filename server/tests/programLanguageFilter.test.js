const { test } = require('node:test');
const assert = require('node:assert/strict');
const Program = require('../src/models/Program');
const { getPrograms } = require('../src/controllers/programController');

test('language filtering accepts stored English and Arabic values and works alongside grouped degree filters', async () => {
  const originalFind = Program.find;
  let query;
  Program.find = (value) => {
    query = value;
    const chain = { select: () => chain, populate: () => chain, sort: () => chain, lean: async () => [] };
    return chain;
  };
  try {
    const res = { set() {}, json() {} };
    await getPrograms({ query: { language: 'English', degreeLevel: 'Master' } }, res, error => { throw error; });
    for (const value of ['English', 'english', 'الإنجليزية']) assert.ok(query.language.$in.some(pattern => pattern.test(value)));
    for (const value of ['Turkish', '30% English + 70% Turkish']) assert.ok(!query.language.$in.some(pattern => pattern.test(value)));
    assert.deepEqual(query.degreeLevel.$in, ['Master', 'Non-Thesis Master', 'Thesis Master']);
    await getPrograms({ query: { language: '30% English + 70% Turkish' } }, res, error => { throw error; });
    assert.ok(query.language.$in.some(pattern => pattern.test('30% English + 70% Turkish')));
    await getPrograms({ query: {} }, res, error => { throw error; });
    assert.equal(query.language, undefined);
  } finally {
    Program.find = originalFind;
  }
});
