const multer = require("multer");
const { validateInput } = require('./requestSafety');
const { checkFile } = require('../utils/fileSafety');

const fileFilter = (req, file, cb) => {
  const allowedTypes = [
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "text/plain",
    "application/zip",
    "application/x-zip-compressed",
    "image/jpeg",
    "image/png",
    "image/webp",
  ];

  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
    return;
  }

  cb(new Error("Unsupported file type"));
};

const upload = multer({
  storage: multer.memoryStorage(),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024, files: 6, fields: 50, fieldSize: 65536, parts: 56 },
});

// Multer populates req.body after the global JSON/request guard has run.
for (const method of ['single', 'array', 'fields', 'any', 'none']) {
  const create = upload[method].bind(upload);
  upload[method] = (...args) => {
    const parse = create(...args);
    return (req, res, next) => parse(req, res, (error) => {
      if (error) return next(error);
      try {
        validateInput(req.body);
        const files = req.file ? [req.file] : Array.isArray(req.files) ? req.files : Object.values(req.files || {}).flat();
        for (const file of files) checkFile(file);
        next();
      } catch (failure) { next(failure); }
    });
  };
}
module.exports = upload;
