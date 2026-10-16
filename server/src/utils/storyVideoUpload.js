const multer = require('multer');
const { randomUUID } = require('node:crypto');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');
const maxBytes = 25 * 1024 * 1024;
const parse = multer({ storage: multer.memoryStorage(), limits: { fileSize: maxBytes, files: 1, fields: 0, parts: 2 },
  fileFilter: (req, file, cb) => cb(null, /\.(mp4|mov)$/i.test(file.originalname) && ['video/mp4', 'video/quicktime'].includes(file.mimetype)),
}).single('file');
const bad = (message, statusCode = 415) => Object.assign(new Error(message), { statusCode });
const parseVideo = (req, res, next) => parse(req, res, error =>
  next(error?.code === 'LIMIT_FILE_SIZE' ? bad('اختر فيديو لا يتجاوز 25 ميجابايت.', 413) : error));
function validateVideo(file) {
  if (!file || file.buffer.length < 12 || file.buffer.subarray(4, 8).toString() !== 'ftyp') throw bad('اختر فيديو MP4 أو MOV صالحًا.');
}
async function uploadStoryVideo(file, owner) {
  validateVideo(file);
  ensureCloudinaryConfigured();
  const result = await new Promise((resolve, reject) => {
    cloudinary.uploader.upload_stream({ resource_type: 'video', folder: `story-videos/${owner}`, public_id: randomUUID(),
      format: 'mp4', transformation: [{ width: 1080, height: 1920, crop: 'limit', video_codec: 'h264', audio_codec: 'aac' }],
    }, (error, asset) => error ? reject(error) : resolve(asset)).end(file.buffer);
  });
  if (!Number.isFinite(result.duration) || result.duration <= 0 || result.duration > 60 || !result.width || !result.height) {
    await cloudinary.uploader.destroy(result.public_id, { resource_type: 'video' }).catch(() => {});
    throw bad('اختر فيديو لا تتجاوز مدته 60 ثانية.', 400);
  }
  return { videoUrl: result.secure_url, duration: result.duration, publicId: result.public_id };
}
module.exports = { parseVideo, validateVideo, uploadStoryVideo, maxBytes };
