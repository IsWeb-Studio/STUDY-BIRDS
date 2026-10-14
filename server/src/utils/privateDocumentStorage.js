const { randomUUID } = require('node:crypto');
const path = require('node:path');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');

function uploadPrivateDocument(file, { contentId } = {}) {
  ensureCloudinaryConfigured();
  const extension = path.extname(file.originalname || '').slice(1).toLowerCase().replace(/[^a-z0-9]/g, '');
  const publicId = `study-birds/private-documents/${contentId || randomUUID()}${extension ? '.' + extension : ''}`;
  return new Promise((resolve, reject) => {
    cloudinary.uploader.upload_stream({ resource_type: 'raw', type: 'authenticated', public_id: publicId, overwrite: false }, (error, result) => {
      if (error) return reject(error);
      if (!result?.public_id || (result.type !== 'authenticated' && !(contentId && result.existing))) return reject(new Error('Private document storage failed'));
      resolve({ publicId: result.public_id, resourceType: 'raw', deliveryType: 'authenticated', format: extension, bytes: result.bytes });
    }).end(file.buffer);
  });
}

function documentDownloadLink(storage) {
  ensureCloudinaryConfigured();
  const expiresAt = Math.floor(Date.now() / 1000) + 120;
  const url = cloudinary.utils.private_download_url(storage.publicId, storage.format || undefined, {
    resource_type: storage.resourceType, type: 'authenticated', expires_at: expiresAt, attachment: true, secure: true,
  });
  return { url, expiresAt };
}
module.exports = { uploadPrivateDocument, documentDownloadLink };
