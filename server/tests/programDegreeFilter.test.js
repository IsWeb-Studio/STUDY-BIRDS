const { test } = require('node:test');
const assert = require('node:assert/strict');
const { buildProgramDegreeFilter } = require('../src/utils/programDegreeFilter');

const degrees = ['Technical Institute', 'Diploma', 'Postgraduate Diploma', 'Bachelor', 'Master', 'Thesis Master', 'Non-Thesis Master', 'PhD'];
const results = (value) => {
  const query = buildProgramDegreeFilter(value);
  return degrees.filter(degree => typeof query === 'string' ? degree === query : query.$in.includes(degree));
};

test('master search includes both thesis variants and existing generic masters', () => {
  assert.deepEqual(results('Master'), ['Master', 'Thesis Master', 'Non-Thesis Master']);
});

test('technical institute/diploma search combines both without postgraduate diplomas', () => {
  assert.deepEqual(results('Technical Institute/Diploma'), ['Technical Institute', 'Diploma']);
  assert.deepEqual(results('Postgraduate Diploma'), ['Postgraduate Diploma']);
});

test('specific-degree API searches remain available to existing clients', () => {
  for (const degree of degrees.filter(degree => degree !== 'Master')) assert.deepEqual(results(degree), [degree]);
});
