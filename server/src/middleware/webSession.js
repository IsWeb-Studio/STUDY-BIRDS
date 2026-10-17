const jwt = require('jsonwebtoken');
const { randomUUID } = require('node:crypto');
const COOKIE = 'studyBirdsRefresh';

// Cookie authentication is restricted to explicitly allowed browser origins.
module.exports = (allowedOrigins) => (req, res, next) => {
  const requestPath = req.path;
  const cookie = String(req.headers.cookie || '').split(';').map(v => v.trim())
    .find(v => v.startsWith(`${COOKIE}=`))?.slice(COOKIE.length + 1);
  const web = req.headers['x-study-birds-client'] === 'web';
  if (!web && !cookie) return next();
  const origin = String(req.headers.origin || '').replace(/\/+$/, '');
  if (!web || (!allowedOrigins.has(origin) && !(req.method === 'GET' && !origin))) return res.status(403).json({ message: 'Browser session origin rejected' });
  const secure = req.secure || process.env.NODE_ENV === 'production' || process.env.RENDER === 'true' ||
    !/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const options = { httpOnly: true, secure, sameSite: secure ? 'none' : 'lax', path: '/api/auth' };
  if (req.path === '/refresh' || req.path === '/logout') {
    // Web callers never choose the refresh credential through JSON.
    req.body = { ...req.body, refreshToken: cookie || '' };
  }
  res.set('Cache-Control', 'no-store');
  const json = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode < 400 && body?.refreshToken) {
      res.cookie(COOKIE, body.refreshToken, { ...options, maxAge: 30 * 86400000 });
      body = { ...body };
      delete body.refreshToken;
      if (body.token) {
        const claims = jwt.verify(body.token, process.env.JWT_SECRET);
        delete claims.exp; delete claims.iat; delete claims.jti;
        body.token = jwt.sign(claims, process.env.JWT_SECRET, { expiresIn: '15m', jwtid: randomUUID() });
      }
    }
    if (requestPath === '/logout' && res.statusCode < 400) res.clearCookie(COOKIE, options);
    return json(body);
  };
  next();
};
