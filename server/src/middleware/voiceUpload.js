const multer = require('multer');
const { validateInput } = require('./requestSafety');
const { validateVoice, MAX_BYTES } = require('../utils/voiceNotes');
const parse = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_BYTES, files: 1, fields: 8, parts: 9, fieldSize: 8192 } }).single('file');
module.exports = (req, res, next) => parse(req, res, error => {
  if (error) return next(error);
  try { validateInput(req.body); validateVoice(req.file); next(); } catch (error) { next(error); }
});
