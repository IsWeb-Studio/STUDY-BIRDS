const { createHmac, timingSafeEqual } = require('node:crypto');

function supportActor(ticketId, message, status, signed, secret = process.env.STUDY_BIRDS_SSO_SECRET, now = Date.now()) {
  if (!signed) return null;
  const { id, name, companyId, issuedAt, signature } = signed;
  if (!secret || typeof id !== 'string' || !id || id.length > 160 || typeof name !== 'string' || !name.trim() || name.length > 160 || typeof companyId !== 'string' || !companyId || companyId.length > 100 || !Number.isSafeInteger(issuedAt) || Math.abs(now - issuedAt) > 300000 || typeof signature !== 'string') throw Object.assign(new Error('Invalid CRM reply identity'), { status: 400 });
  const body = JSON.stringify({ ticketId: String(ticketId), message, status, id, name, companyId, issuedAt });
  const expected = createHmac('sha256', secret).update(body).digest('hex');
  if (!/^[a-f0-9]{64}$/.test(signature) || !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) throw Object.assign(new Error('Invalid CRM reply signature'), { status: 400 });
  return { displayName: name.trim(), source: 'crm', crmActorId: id };
}

module.exports = { supportActor };
