const {createHash, timingSafeEqual} = require('node:crypto');

const PREFIX = 'sbcrm_';
const families = new Set(['admin', 'crm', 'shared-read', 'universities', 'programs',
  'scholarships', 'applications', 'consultations', 'service-requests', 'content',
  'mobile-workspace', 'documents', 'payment-proofs', 'support-attachments']);

// Dedicated server credential: never accepted as a browser login/session token.
async function authenticateCrmService(req, token, env, findUser) {
  if (!token.startsWith(PREFIX)) return null;
  const fail = (status, message) => { throw Object.assign(new Error(message), {statusCode: status, status}); };
  const hash = env.CRM_SERVICE_TOKEN_SHA256 || '';
  const userId = env.CRM_SERVICE_USER_ID || '';
  if (env.CRM_SERVICE_AUTH_ENABLED !== 'true' || !/^[a-f\d]{64}$/i.test(hash) ||
      !/^[a-f\d]{24}$/i.test(userId) || !/^sbcrm_[a-f\d]{64}$/.test(token)) {
    fail(401, 'CRM service credential is disabled or invalid');
  }
  const actual = createHash('sha256').update(token).digest();
  if (!timingSafeEqual(actual, Buffer.from(hash, 'hex'))) fail(401, 'Invalid CRM service credential');
  const pathname = (req.originalUrl || '').split('?')[0];
  const family = pathname.split('/')[2];
  if (req.headers.origin || req.headers['x-study-birds-client'] ||
      !(families.has(family) || (pathname === '/api/auth/me' && req.method === 'GET'))) {
    fail(403, 'CRM credential is restricted to backend integration APIs');
  }
  const user = await findUser(userId);
  if (!user || !user.isActive || user.role !== 'admin') fail(403, 'CRM service account is unavailable');
  req.crmServiceAuthenticated = true;
  return user;
}

module.exports = {authenticateCrmService};
