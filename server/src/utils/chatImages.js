const crypto = require('node:crypto');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');

// Chat attachments use authenticated delivery; public story URLs are never reused.
async function uploadChatImage(file, owner) {
  ensureCloudinaryConfigured();
  return new Promise((resolve, reject) => {
    cloudinary.uploader.upload_stream({
      resource_type: 'image', type: 'authenticated',
      public_id: `chat-images/${owner}/${crypto.randomUUID()}`, format: 'jpg',
      transformation: [{ width: 1600, height: 1600, crop: 'limit' }, { quality: 'auto' }],
    }, (error, result) => error ? reject(error) : resolve({ publicId: result.public_id, format: result.format }))
      .end(file.buffer);
  });
}
async function readChatImage(image) {
  ensureCloudinaryConfigured();
  const url = cloudinary.url(image.publicId, { resource_type: 'image', type: 'authenticated',
    secure: true, sign_url: true, format: image.format || 'jpg' });
  const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw Object.assign(new Error('Image unavailable'), { statusCode: 502 });
  return Buffer.from(await response.arrayBuffer());
}
module.exports = { uploadChatImage, readChatImage };
