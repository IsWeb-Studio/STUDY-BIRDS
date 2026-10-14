const { test } = require('node:test');
const assert = require('node:assert/strict');
const { legacyAsset, privatizeLegacyDocument } = require('../src/utils/legacyDocumentStorage');

test('legacy migration validates ownership of storage host and correctly parses raw/image identities', () => {
  assert.equal(legacyAsset('https://res.cloudinary.com/owned/raw/upload/v123/study-birds/file.pdf', 'owned').publicId, 'study-birds/file.pdf');
  assert.equal(legacyAsset('https://res.cloudinary.com/owned/image/upload/v123/study-birds/file.jpg', 'owned').publicId, 'study-birds/file');
  for (const url of ['https://example.com/file.pdf', 'https://res.cloudinary.com/other/raw/upload/v123/file.pdf',
    'http://res.cloudinary.com/owned/raw/upload/v123/file.pdf']) assert.throws(() => legacyAsset(url, 'owned'));
});

test('privatization changes delivery type without deleting or copying the asset and retries safely', async () => {
  let writes = 0, saved;
  const provider = {
    uploader: { async rename(from, to, options) {
      assert.equal(from, 'study-birds/file.pdf'); assert.equal(options.to_type, 'authenticated');
      assert.equal(options.overwrite, false); assert.equal(options.invalidate, true);
      if (saved) throw new Error('Original already moved');
      writes++; saved = { public_id: to, type: 'authenticated', bytes: 42 }; return saved;
    } },
    api: { async resource(id, options) { assert.equal(id, saved.public_id); assert.equal(options.type, 'authenticated'); return saved; } },
  };
  const document = { filePath: 'https://res.cloudinary.com/owned/raw/upload/v123/study-birds/file.pdf' };
  const first = await privatizeLegacyDocument(document, provider, 'owned');
  const retry = await privatizeLegacyDocument(document, provider, 'owned');
  assert.deepEqual(first, retry); assert.equal(writes, 1); assert.equal(first.deliveryType, 'authenticated');
});
