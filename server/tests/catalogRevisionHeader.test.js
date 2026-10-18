const { test } = require('node:test');
const assert = require('node:assert/strict');
const { withRevisionHeader, expectedVersion } = require('../src/utils/catalogRevision');
test('revision header preserves preconditions for a bodyless deletion', () => {
  const req = { get: () => '"3"' };
  withRevisionHeader(req, {}, error => assert.equal(error, undefined));
  assert.equal(expectedVersion(req.body), 3);
});
test('body revision wins and malformed/missing preconditions cannot bypass checks', () => {
  const req = { body: { expectedVersion: 1 }, get: () => '"3"' };
  withRevisionHeader(req, {}, error => assert.equal(error, undefined));
  assert.equal(expectedVersion(req.body), 1);
  for (const header of ['*', '"-1"', '"9007199254740992"', 'bad']) {
    withRevisionHeader({ get: () => header }, {}, error => assert.equal(error.status, 400));
  }
  assert.throws(() => expectedVersion({}), { status: 428 });
});
