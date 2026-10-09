const path = require('node:path');
function checkFile(file) {
  const buffer = file?.buffer;
  const extension = path.extname(file?.originalname || '').toLowerCase();
  const types = {
    '.pdf': ['application/pdf'], '.jpg': ['image/jpeg'], '.jpeg': ['image/jpeg'],
    '.png': ['image/png'], '.webp': ['image/webp'], '.txt': ['text/plain'],
    '.zip': ['application/zip', 'application/x-zip-compressed'],
    '.doc': ['application/msword'], '.xls': ['application/vnd.ms-excel'], '.ppt': ['application/vnd.ms-powerpoint'],
    '.docx': ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    '.xlsx': ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    '.pptx': ['application/vnd.openxmlformats-officedocument.presentationml.presentation'],
  };
  const fail = () => { const error = new Error('نوع الملف غير مدعوم أو لا يتطابق مع محتواه. اختر ملفًا صحيحًا.'); error.statusCode = 415; throw error; };
  if (!Buffer.isBuffer(buffer) || !buffer.length || !types[extension]?.includes(file.mimetype)) fail();
  if (buffer.length > 5 * 1024 * 1024) { const error = new Error('اختر ملفًا لا يتجاوز 5 ميجابايت.'); error.statusCode = 413; throw error; }
  const starts = (hex) => buffer.subarray(0, hex.length / 2).equals(Buffer.from(hex, 'hex'));
  let valid = false;
  if (extension === '.pdf') valid = buffer.subarray(0, 5).toString() === '%PDF-';
  if (['.jpg', '.jpeg'].includes(extension)) valid = starts('ffd8ff');
  if (extension === '.png') valid = starts('89504e470d0a1a0a');
  if (extension === '.webp') valid = buffer.subarray(0, 4).toString() === 'RIFF' && buffer.subarray(8, 12).toString() === 'WEBP';
  if (['.zip', '.docx', '.xlsx', '.pptx'].includes(extension)) valid = starts('504b0304') || starts('504b0506');
  if (['.doc', '.xls', '.ppt'].includes(extension)) valid = starts('d0cf11e0a1b11ae1');
  if (extension === '.txt') valid = !buffer.includes(0) && !/<\s*(?:script|iframe|svg|object|embed)\b|<[^>]+\bon\w+\s*=/i.test(buffer.toString('utf8'));
  if (!valid) fail();
}
module.exports = { checkFile };
