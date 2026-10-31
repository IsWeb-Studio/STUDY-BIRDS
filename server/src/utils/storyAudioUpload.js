const multer = require('multer');
const { randomUUID } = require('node:crypto');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');
const bad = (message, statusCode = 415) => Object.assign(new Error(message), { statusCode });
const parse = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024, files: 1, fields: 0, parts: 2 },
  fileFilter: (req, file, cb) => cb(null, /\.(mp3|m4a|wav)$/i.test(file.originalname) && ['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-wav'].includes(file.mimetype)),
}).single('file');
const parseAudio = (req, res, next) => parse(req, res, error => next(error?.code === 'LIMIT_FILE_SIZE' ? bad('Audio exceeds 10 MB', 413) : error));
function validateAudio(file) {
  const b = file?.buffer;
  if (!b || b.length < 12) throw bad('Invalid audio');
  const ext = file.originalname.split('.').pop().toLowerCase();
  const valid = ext === 'mp3' ? (b.subarray(0, 3).toString() === 'ID3' || (b[0] === 255 && (b[1] & 224) === 224))
    : ext === 'wav' ? (b.subarray(0, 4).toString() === 'RIFF' && b.subarray(8, 12).toString() === 'WAVE')
    : ext === 'm4a' && b.subarray(4, 8).toString() === 'ftyp';
  if (!valid) throw bad('Invalid audio');
}
async function uploadStoryAudio(file, owner) {
  validateAudio(file);
  ensureCloudinaryConfigured();
  const asset = await new Promise((resolve, reject) => {
    cloudinary.uploader.upload_stream({ resource_type: 'video', folder: `story-audio/${owner}`, public_id: randomUUID(), format: 'mp3' },
      (error, result) => error ? reject(error) : resolve(result)).end(file.buffer);
  });
  if (!Number.isFinite(asset.duration) || asset.duration <= 0 || asset.duration > 60 || asset.width || asset.height) {
    await cloudinary.uploader.destroy(asset.public_id, { resource_type: 'video' }).catch(() => {});
    throw bad('Choose audio up to 60 seconds', 400);
  }
  return { audioUrl: asset.secure_url, duration: asset.duration, publicId: asset.public_id };
}
module.exports = { parseAudio, validateAudio, uploadStoryAudio };
