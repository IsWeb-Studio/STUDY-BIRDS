const express = require('express');
const mongoose = require('mongoose');
const { randomUUID, createHmac, timingSafeEqual } = require('node:crypto');
const { protect } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const Invoice = require('../models/Invoice');
const Receipt = require('../models/StripePaymentReceipt');
const { financialTransaction } = require('../utils/financialTransaction');
const { minorUnits, outstandingMinor, hasCardAttempt, fail } = require('../utils/financialPolicy');
const { enqueueFinancialNotice, drainFinancialOutbox } = require('../utils/financialOutbox');
const router = express.Router();
const stripeEnabled = () => Boolean(process.env.STRIPE_SECRET_KEY);

async function stripeRequest(path, params, idempotencyKey) {
  if (!stripeEnabled()) fail(503, 'Stripe not configured');
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: params ? 'POST' : 'GET',
    headers: {
      Authorization: `Basic ${Buffer.from(`${process.env.STRIPE_SECRET_KEY}:`).toString('base64')}`,
      ...(params ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
      ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}),
    },
    ...(params ? { body: new URLSearchParams(params).toString() } : {}),
    signal: AbortSignal.timeout(15000),
  });
  const data = await response.json();
  if (!response.ok) fail(502, 'Stripe request failed; reconcile or retry the same attempt');
  return data;
}
function verifyStripeSignature(raw, header) {
  if (!process.env.STRIPE_WEBHOOK_SECRET || !Buffer.isBuffer(raw) || typeof header !== 'string') return null;
  const parts = header.split(',').map(p => p.trim().split('='));
  const timestamp = parts.find(p => p[0] === 't')?.[1];
  if (!/^\d+$/.test(timestamp || '') || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) return null;
  const expected = createHmac('sha256', process.env.STRIPE_WEBHOOK_SECRET).update(`${timestamp}.`).update(raw).digest();
  return parts.filter(p => p[0] === 'v1' && /^[a-f\d]{64}$/i.test(p[1] || ''))
    .some(p => timingSafeEqual(expected, Buffer.from(p[1], 'hex'))) ? JSON.parse(raw.toString('utf8')) : null;
}
const keys = (student, invoice) => [`wallet:${student}`, `invoice:${invoice}`];
const clearAttempt = invoice => {
  for (const field of ['stripeSessionId', 'stripeCheckoutKey', 'stripeCheckoutPayload', 'stripeCheckoutCreatedAt',
    'stripeSnapshot', 'stripeExpectedAmount', 'stripeExpectedCurrency', 'stripeCheckoutExpiresAt', 'stripeCheckoutUrl']) invoice[field] = undefined;
};
function sameSnapshot(invoice) {
  const saved = invoice.stripeSnapshot;
  return !saved || saved.amount == null || (saved.amount === invoice.amount &&
    saved.walletCreditApplied === (invoice.walletCreditApplied || 0) && saved.crmPaidAmount === (invoice.crmPaidAmount || 0) &&
    saved.currency === (invoice.currency || 'USD').toLowerCase());
}
function matchesAttempt(invoice, payment) {
  if (invoice.stripeCheckoutKey) return payment.metadata?.checkoutKey === invoice.stripeCheckoutKey &&
    (!invoice.stripeSessionId || invoice.stripeSessionId === payment.id);
  return Boolean(invoice.stripeSessionId && invoice.stripeSessionId === payment.id);
}
router.get('/status', (req, res) => res.json({ enabled: stripeEnabled() }));

router.post('/checkout', protect, run(async (req, res) => {
  const { invoiceId } = req.body;
  if (req.user.role !== 'student') fail(403, 'Forbidden');
  if (!mongoose.isValidObjectId(invoiceId)) fail(400, 'Invalid invoice ID');
  if (!stripeEnabled()) fail(503, 'Stripe not configured');
  const attempt = await financialTransaction(keys(req.user._id, invoiceId), async session => {
    const invoice = await Invoice.findOne({ _id: invoiceId, student: req.user._id, status: 'unpaid' }).select('+stripeCheckoutPayload').session(session);
    if (!invoice) fail(404, 'Invoice not found or already paid');
    if (invoice.stripeReconciliationRequired) fail(409, 'Payment requires reconciliation');
    if (invoice.stripeSessionId) {
      if (invoice.stripeCheckoutExpiresAt > new Date() && invoice.stripeCheckoutUrl) return { url: invoice.stripeCheckoutUrl, sessionId: invoice.stripeSessionId };
      fail(409, 'Cancel or reconcile the previous card attempt before creating another');
    }
    if (invoice.stripeCheckoutKey) {
      // Stripe can prune idempotency keys after 24h: never recreate an uncertain
      // external payment after that window with the same key.
      if (!invoice.stripeCheckoutPayload || Date.now() - invoice.stripeCheckoutCreatedAt.getTime() > 23 * 3600000) fail(409, 'Payment attempt requires reconciliation');
      return { key: invoice.stripeCheckoutKey, payload: invoice.stripeCheckoutPayload };
    }
    const amount = outstandingMinor(invoice);
    if (amount <= 0) fail(400, 'No outstanding amount');
    const currency = (invoice.currency || 'USD').toLowerCase();
    const key = randomUUID(), expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const origin = process.env.CLIENT_URL || 'https://studybirds.net';
    const payload = {
      'payment_method_types[]': 'card', 'line_items[0][price_data][currency]': currency,
      'line_items[0][price_data][unit_amount]': String(amount),
      'line_items[0][price_data][product_data][name]': invoice.description || `Invoice ${invoice.invoiceNumber}`,
      'line_items[0][quantity]': '1', mode: 'payment', expires_at: String(expiresAt),
      success_url: `${origin}/student/payments?stripe=success&invoice=${invoice._id}`,
      cancel_url: `${origin}/student/payments?stripe=cancel`,
      'metadata[invoiceId]': String(invoice._id), 'metadata[studentId]': String(req.user._id), 'metadata[checkoutKey]': key,
    };
    invoice.stripeCheckoutKey = key; invoice.stripeCheckoutPayload = payload;
    invoice.stripeCheckoutCreatedAt = new Date(); invoice.stripeCheckoutExpiresAt = new Date(expiresAt * 1000);
    invoice.stripeExpectedAmount = amount; invoice.stripeExpectedCurrency = currency;
    invoice.stripeSnapshot = { amount: invoice.amount, walletCreditApplied: invoice.walletCreditApplied || 0,
      crmPaidAmount: invoice.crmPaidAmount || 0, currency };
    invoice.increment(); await invoice.save({ session });
    return { key, payload };
  });
  if (attempt.url) return res.json(attempt);
  // No network call inside a retryable database transaction.
  const checkout = await stripeRequest('checkout/sessions', attempt.payload, attempt.key);
  if (typeof checkout.id !== 'string' || !/^cs_[A-Za-z0-9_]+$/.test(checkout.id) ||
      typeof checkout.url !== 'string' || !checkout.url.startsWith('https://checkout.stripe.com/')) fail(502, 'Invalid Stripe checkout response');
  await financialTransaction(keys(req.user._id, invoiceId), async session => {
    const invoice = await Invoice.findOne({ _id: invoiceId, student: req.user._id, stripeCheckoutKey: attempt.key }).session(session);
    if (!invoice || invoice.status !== 'unpaid' || invoice.stripeReconciliationRequired) fail(409, 'Payment attempt already completed or changed');
    if (invoice.stripeSessionId && invoice.stripeSessionId !== checkout.id) fail(409, 'Payment identity mismatch');
    invoice.stripeSessionId = checkout.id; invoice.stripeCheckoutUrl = checkout.url;
    invoice.increment(); await invoice.save({ session });
  });
  res.json({ url: checkout.url, sessionId: checkout.id });
}));

// A clock expiring locally is not proof that no card payment was collected.
router.post('/cancel-checkout', protect, run(async (req, res) => {
  if (req.user.role !== 'student' || !mongoose.isValidObjectId(req.body.invoiceId)) fail(400, 'Invalid invoice');
  const invoice = await Invoice.findOne({ _id: req.body.invoiceId, student: req.user._id });
  if (!invoice || !invoice.stripeSessionId || invoice.stripeReconciliationRequired) fail(409, 'Payment requires reconciliation or checkout retry');
  const id = invoice.stripeSessionId;
  let remote = await stripeRequest(`checkout/sessions/${encodeURIComponent(id)}`);
  if (remote.status === 'open') remote = await stripeRequest(`checkout/sessions/${encodeURIComponent(id)}/expire`, {});
  if (remote.id !== id || remote.status !== 'expired' || remote.payment_status === 'paid' ||
      remote.metadata?.invoiceId !== String(invoice._id) || remote.metadata?.studentId !== String(req.user._id)) fail(409, 'Payment is not confirmed expired; wait for reconciliation');
  await financialTransaction(keys(req.user._id, invoice._id), async session => {
    const current = await Invoice.findById(invoice._id).session(session);
    if (!current || current.stripeSessionId !== id || current.status !== 'unpaid' || current.stripeReconciliationRequired || await Receipt.exists({ _id: id }).session(session)) fail(409, 'Payment changed');
    clearAttempt(current); current.increment(); await current.save({ session });
  });
  res.json({ cancelled: true });
}));

router.post('/webhook', express.raw({ type: 'application/json', limit: '100kb' }), run(async (req, res) => {
  let event;
  try { event = verifyStripeSignature(req.rawBody || req.body, req.headers['stripe-signature']); } catch { /* reject below */ }
  if (!event) fail(400, 'Invalid signature');
  if (event.type !== 'checkout.session.completed' || event.data?.object?.payment_status !== 'paid') return res.json({ received: true });
  const payment = event.data.object, invoiceId = payment.metadata?.invoiceId, studentId = payment.metadata?.studentId;
  if (!mongoose.isValidObjectId(invoiceId) || !mongoose.isValidObjectId(studentId) ||
      typeof payment.id !== 'string' || !/^cs_[A-Za-z0-9_]+$/.test(payment.id) || typeof event.id !== 'string' ||
      !Number.isSafeInteger(payment.amount_total) || payment.amount_total <= 0 || typeof payment.currency !== 'string') fail(400, 'Invalid payment event');
  await financialTransaction(keys(studentId, invoiceId), async session => {
    if (await Receipt.exists({ _id: payment.id }).session(session)) return;
    const invoice = await Invoice.findOne({ _id: invoiceId, student: studentId }).session(session);
    const matched = invoice && matchesAttempt(invoice, payment);
    let applicable = false;
    if (matched && invoice.status === 'unpaid' && !invoice.stripeReconciliationRequired) {
      try {
        applicable = sameSnapshot(invoice) && invoice.stripeExpectedAmount === payment.amount_total &&
          invoice.stripeExpectedCurrency === payment.currency && (invoice.currency || 'USD').toLowerCase() === payment.currency &&
          outstandingMinor(invoice) === payment.amount_total;
      } catch { applicable = false; }
    }
    await Receipt.create([{
      _id: payment.id, eventId: event.id, invoice: invoiceId, student: studentId,
      amountMinor: payment.amount_total, currency: payment.currency,
      state: applicable ? 'applied' : 'reconciliation', reason: applicable ? undefined : 'Invoice or checkout snapshot mismatch',
    }], { session });
    if (invoice) {
      if (matched) invoice.stripeSessionId = payment.id;
      if (applicable) { invoice.status = 'paid'; invoice.reviewedAt = new Date(); }
      else invoice.stripeReconciliationRequired = true;
      invoice.stripeCheckoutUrl = undefined; invoice.stripeCheckoutPayload = undefined;
      invoice.increment(); await invoice.save({ session });
    }
    if (invoice) await enqueueFinancialNotice(`stripe:${payment.id}`, {
      user: studentId, title: applicable ? 'Payment received' : 'Payment requires reconciliation',
      message: applicable ? `Invoice ${invoice.invoiceNumber} paid` : 'A card payment was received and requires financial review.',
      link: '/student/payments', advancePayment: applicable,
    }, session);
  });
  await drainFinancialOutbox().catch(() => {});
  res.json({ received: true });
}));
module.exports = router;
