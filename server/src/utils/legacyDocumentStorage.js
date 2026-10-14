const path = require('node:path');
const { createHash } = require('node:crypto');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');

function legacyAsset(url, cloudName) {
  const uri = new URL(url);
  const parts = uri.pathname.slice(1).split('/');
  if (uri.protocol !== 'https:' || uri.hostname !== 'res.cloudinary.com' ||
      parts[0] !== cloudName || !['image', 'raw', 'video'].includes(parts[1]) ||
      !['upload', 'private', 'authenticated'].includes(parts[2])) throw new Error('Unsupported legacy storage');
  let start = 3;
  if (/^v\d+$/.test(parts[start])) start++;
  const source = decodeURIComponent(parts.slice(start).join('/'));
  if (!source || source.includes('..') || /[\x00-\x1f]/.test(source)) throw new Error('Invalid legacy identity');
  const extension = path.posix.extname(source).slice(1).toLowerCase();
  if (extension && !/^[a-z0-9]+$/.test(extension)) throw new Error('Invalid legacy format');
  const publicId = parts[1] === 'raw' || !extension ? source : source.slice(0, -(extension.length + 1));
  const key = createHash('sha256').update(`${cloudName}:${parts[1]}:${parts[2]}:${publicId}`).digest('hex');
  return { publicId, resourceType: parts[1], deliveryType: parts[2], format: extension,
    target: `study-birds/private-documents/legacy-${key}${parts[1] === 'raw' && extension ? '.' + extension : ''}` };
}

async function privatizeLegacyDocument(document, provider = cloudinary, cloudName = process.env.CLOUDINARY_CLOUD_NAME) {
  if (provider === cloudinary) ensureCloudinaryConfigured();
  const source = legacyAsset(document.filePath, cloudName);
  let result;
  try {
    result = await provider.uploader.rename(source.publicId, source.target, {
      resource_type: source.resourceType, type: source.deliveryType, to_type: 'authenticated',
      overwrite: false, invalidate: true,
    });
  } catch (error) {
    // Handles a lost DB acknowledgement or another legacy record for the same
    // physical object. The deterministic target is already private in that case.
    result = await provider.api.resource(source.target, {
      resource_type: source.resourceType, type: 'authenticated',
    });
  }
  if (result.public_id !== source.target || result.type !== 'authenticated') throw new Error('Private migration not confirmed');
  return { publicId: result.public_id, resourceType: source.resourceType, deliveryType: 'authenticated',
    format: result.format || source.format, bytes: result.bytes };
}

module.exports = { legacyAsset, privatizeLegacyDocument };
