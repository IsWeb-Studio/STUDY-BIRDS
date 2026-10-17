const { cloudinary } = require('../config/cloudinary');
const { legacyAsset, privatizeLegacyDocument } = require('./legacyDocumentStorage');

async function migrateVerificationDocument(document, provider = cloudinary, cloudName = process.env.CLOUDINARY_CLOUD_NAME) {
  if (document.storage?.deliveryType === 'authenticated' && document.storage.publicId) return document.storage;
  const source = legacyAsset(document.filePath, cloudName);
  // Never migrate arbitrary assets supplied through a corrupted database record.
  if (!source.publicId.startsWith('study-birds/agent-verification/')) {
    throw new Error('Unexpected verification asset folder');
  }
  const storage = await privatizeLegacyDocument(document, provider, cloudName);
  // A successful retry lookup alone must not hide a still-public original.
  let original;
  try {
    original = await provider.api.resource(source.publicId, {
      resource_type: source.resourceType, type: source.deliveryType,
    });
  } catch (error) {
    if (Number(error.http_code ?? error.error?.http_code) !== 404) throw error;
  }
  if (original) throw new Error('Original asset is still accessible; migration not complete');
  return storage;
}
module.exports = { migrateVerificationDocument };
