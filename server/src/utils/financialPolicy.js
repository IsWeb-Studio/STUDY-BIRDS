const { createHash, randomUUID } = require('node:crypto');
const decimals = { usd: 2, eur: 2, gbp: 2, try: 2, aed: 2, egp: 2, sar: 2, jod: 3, jpy: 0 };
function fail(status, message) { throw Object.assign(new Error(message), { statusCode: status }); }
function minorUnits(amount, currency = 'USD') {
  const places = decimals[String(currency).toLowerCase()];
  const scaled = amount * 10 ** places;
  const rounded = Math.round(scaled);
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount < 0 || places === undefined ||
      !Number.isSafeInteger(rounded) || Math.abs(scaled - rounded) > 0.000001) fail(400, 'Invalid monetary amount or currency');
  return rounded;
}
function operationKey(req, scope) {
  const supplied = req.headers?.['idempotency-key'];
  if (supplied !== undefined && (typeof supplied !== 'string' || !/^[A-Za-z0-9._:-]{1,128}$/.test(supplied))) fail(400, 'Invalid idempotency key');
  return supplied ? createHash('sha256').update(`${scope}:${supplied}`).digest('hex') : randomUUID();
}
function outstandingMinor(invoice) {
  return minorUnits(invoice.amount, invoice.currency || 'USD') -
    minorUnits(invoice.walletCreditApplied || 0, invoice.currency || 'USD') -
    minorUnits(invoice.crmPaidAmount || 0, invoice.currency || 'USD');
}
const hasCardAttempt = invoice => Boolean(invoice.stripeCheckoutKey || invoice.stripeSessionId || invoice.stripeReconciliationRequired);
module.exports = { minorUnits, outstandingMinor, operationKey, hasCardAttempt, fail };
