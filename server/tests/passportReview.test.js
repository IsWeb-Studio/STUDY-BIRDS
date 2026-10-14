const test = require('node:test');
const assert = require('node:assert/strict');
const Document = require('../src/models/Document');
const fields = { number: 'TEST123', name: 'EXAMPLE PERSON', nationality: 'UTO', birth: '1990-01-02', expiry: '2035-01-02', sex: 'F' };
const payload = (reviewed = fields) => JSON.stringify({ extracted: fields, reviewed, clientReportedMrzChecksPassed: true,
  manualReviewRequired: false, correctedFields: [], status: 'verified' });
test('client claims never become trusted verification; corrections are computed server-side', () => {
  const review = Document.parsePassportReview(payload({ ...fields, number: 'TEST456' }));
  assert.equal(review.manualReviewRequired, true);
  assert.deepEqual(review.correctedFields, ['number']);
  assert.equal(review.extracted.number, 'TEST123');
  assert.equal(review.reviewed.number, 'TEST456');
  assert.equal(review.status, undefined);
  const doc = new Document({ student: '000000000000000000000001', type: 'passport', fileName: 'test.jpg', filePath: '/private', passportReview: review });
  assert.equal(doc.status, 'pending');
  assert.equal(doc.validateSync(), undefined);
});
test('rejects malformed, incomplete, oversized and impossible-date metadata', () => {
  for (const input of ['not json', '{}', 'x'.repeat(5001), payload({ ...fields, birth: '1990-02-31' }),
    payload({ ...fields, name: '' }), payload({ ...fields, nationality: '??' }), payload({ ...fields, expiry: '1980-01-01' })]) {
    assert.throws(() => Document.parsePassportReview(input));
  }
});
