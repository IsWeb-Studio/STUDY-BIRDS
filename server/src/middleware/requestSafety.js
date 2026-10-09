const { randomUUID } = require('node:crypto');
const { publicMessage } = require('../utils/publicError');

function invalid(message = 'صيغة البيانات غير صالحة. راجع الحقول المدخلة.') {
  const error = new Error(message);
  error.statusCode = 400;
  error.code = 'INVALID_INPUT';
  return error;
}

// Reject query operators instead of silently deleting them and widening a query.
function validateInput(value, { query = false } = {}) {
  let nodes = 0;
  const opaque = /^(?:password|currentPassword|newPassword|confirmation|credential|token|refreshToken|idToken|clientDataJSON|attestationObject|signature|authenticatorData|rawId|verifier)$/i;
  function visit(item, depth, key = '') {
    if (++nodes > 20000 || depth > 16) throw invalid('البيانات معقّدة أو كبيرة جدًا. قلّل حجم الطلب.');
    if (typeof item === 'string') {
      if (item.length > (query ? 500 : 65536) || item.includes('\0')) throw invalid('بعض الحقول طويلة جدًا أو غير صالحة.');
      if (!opaque.test(key) && /<\s*\/?\s*(?:script|iframe|object|embed|svg|math)\b|<[^>]+\bon\w+\s*=|(?:javascript|vbscript)\s*:/i.test(item)) {
        throw invalid('يحتوي أحد الحقول على محتوى غير مسموح. استخدم نصًا أو رابطًا آمنًا.');
      }
      return;
    }
    if (Array.isArray(item)) {
      if (item.length > 1000) throw invalid('عدد العناصر أكبر من المسموح.');
      for (const child of item) visit(child, depth + 1, key);
      return;
    }
    if (item && typeof item === 'object') {
      if (query && depth > 0) throw invalid('صيغة البحث غير صالحة. استخدم قيمة نصية للبحث.');
      for (const [name, child] of Object.entries(item)) {
        if (name.startsWith('$') || name.includes('.') || ['__proto__', 'prototype', 'constructor'].includes(name)) throw invalid();
        visit(child, depth + 1, name);
      }
    }
  }
  visit(value, 0);
}

function requestSafety(req, res, next) {
  try {
    validateInput(req.query, { query: true });
    // Signed provider payloads are verified by their own webhook handler.
    if (req.path !== '/payments/stripe/webhook') validateInput(req.body);
    next();
  } catch (error) { next(error); }
}

function safeResponses(req, res, next) {
  res.setHeader('X-Request-Id', randomUUID());
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  const json = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode >= 400 && body && typeof body === 'object' && !Array.isArray(body)) {
      const { stack, error, ...safe } = body;
      body = { ...safe, message: publicMessage(res.statusCode, body.message) };
    }
    return json(body);
  };
  next();
}

function escapeSearch(value) {
  return String(value ?? '').trim().slice(0, 200).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
module.exports = { validateInput, requestSafety, safeResponses, escapeSearch, invalid };
