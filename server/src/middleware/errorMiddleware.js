const { publicMessage } = require('../utils/publicError');
const notFound = (req, res, next) => {
  const error = new Error('المحتوى المطلوب غير متاح حاليًا.');
  res.status(404);
  next(error);
};

const errorHandler = (error, req, res, next) => {
  if (res.headersSent) return next(error);
  // Errors may carry their own client status (e.g. a busy lease → 409).
  const carried = error.statusCode || error.status;
  let statusCode = res.statusCode >= 400 ? res.statusCode :
    (Number.isInteger(carried) && carried >= 400 && carried <= 599 ? carried : 500);
  let message = error.message;
  if (error.name === 'CastError' || error.name === 'ValidationError' || error.type === 'entity.parse.failed') statusCode = 400;
  if (error.type === 'entity.too.large') statusCode = 413;
  if (error.code === 11000) { statusCode = 409; message = error.keyPattern?.email ? 'Email already in use' : ''; }
  if (error.message === 'Unsupported file type') statusCode = 415;
  if (error.name === 'MulterError') {
    statusCode = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
    message = error.code === 'LIMIT_FILE_SIZE' ? 'اختر ملفًا لا يتجاوز 5 ميجابايت.' : 'عدد الملفات أو حقول الرفع غير مسموح. اختر الملف مجددًا.';
  }
  if (statusCode >= 500) console.error('[request-failed]', { requestId: res.getHeader?.('X-Request-Id'), name: error.name, code: error.code });

  res.status(statusCode).json({
    message: publicMessage(statusCode, message),
  });
};

module.exports = {
  notFound,
  errorHandler,
};
