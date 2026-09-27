// #34: Stripe payment gateway — uses raw fetch so no stripe npm package needed.
// Required env vars: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, CLIENT_URL
const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const Invoice = require('../models/Invoice');
const StudentWalletEntry = require('../models/StudentWalletEntry');
const Notification = require('../models/Notification');
const { sendPushToUser } = require('../utils/pushNotifications');

const router = express.Router();
const { withLease } = require('../utils/leaseLock');
const mongoose = require('mongoose');

const stripeEnabled = () => Boolean(process.env.STRIPE_SECRET_KEY);

async function stripePost(path, params) {
  if (!stripeEnabled()) throw Object.assign(new Error('Stripe not configured'), { httpStatus: 503 });
  const res = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${process.env.STRIPE_SECRET_KEY}:`).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams(params).toString(),
    signal: AbortSignal.timeout(15000),
  });
  const data = await res.json();
  if (!res.ok) throw Object.assign(new Error(data.error?.message || 'Stripe error'), { httpStatus: 502 });
  return data;
}

function verifyStripeSignature(rawBody, sigHeader) {
  if (!process.env.STRIPE_WEBHOOK_SECRET) return null;
  const { createHmac, timingSafeEqual } = require('node:crypto');
  if (!Buffer.isBuffer(rawBody) || typeof sigHeader !== 'string') return null;
  const parts = sigHeader.split(',').map(p => p.trim().split('='));
  const timestamp = parts.find(p => p[0] === 't')?.[1];
  if (!/^\d+$/.test(timestamp || '') || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) return null;
  const expected = createHmac('sha256', process.env.STRIPE_WEBHOOK_SECRET)
    .update(`${timestamp}.`).update(rawBody).digest();
  const valid = parts.filter(p => p[0] === 'v1' && /^[a-f\d]{64}$/i.test(p[1] || ''))
    .some(p => timingSafeEqual(expected, Buffer.from(p[1], 'hex')));
  return valid ? JSON.parse(rawBody.toString('utf8')) : null;
}

router.get('/status', (req, res) => res.json({ enabled: stripeEnabled() }));

router.post('/checkout', protect, run(async (req, res) => {
  const { invoiceId } = req.body;
  if (req.user.role !== 'student') return res.status(403).json({ message: 'Forbidden' });
  if (!mongoose.isValidObjectId(invoiceId)) return res.status(400).json({ message: 'invoiceId required' });
  await withLease(`wallet:${req.user._id}`, async () => {
  const invoice = await Invoice.findOne({ _id: invoiceId, student: req.user._id, status: 'unpaid' });
  if (!invoice) return res.status(404).json({ message: 'Invoice not found or already paid' });
  if (invoice.stripeCheckoutExpiresAt > new Date() && invoice.stripeCheckoutUrl) return res.json({ url: invoice.stripeCheckoutUrl, sessionId: invoice.stripeSessionId });
  const currency = (invoice.currency || 'USD').toLowerCase();
  const decimals = { usd: 2, eur: 2, gbp: 2, try: 2, aed: 2, egp: 2, sar: 2, jod: 3, jpy: 0 }[currency];
  if (decimals === undefined) return res.status(400).json({ message: 'Unsupported invoice currency' });
  const amount = Math.round((invoice.amount - (invoice.walletCreditApplied || 0)) * 10 ** decimals);
  if (!Number.isSafeInteger(amount) || amount <= 0) return res.status(400).json({ message: 'No outstanding amount' });
  const expiresAt = Math.floor(Date.now() / 1000) + 31 * 60;
  const origin = process.env.CLIENT_URL || 'https://studybirds.net';
  const session = await stripePost('checkout/sessions', {
    'payment_method_types[]': 'card',
    'line_items[0][price_data][currency]': currency,
    'line_items[0][price_data][unit_amount]': String(amount),
    'line_items[0][price_data][product_data][name]': invoice.description || `Invoice ${invoice.invoiceNumber}`,
    'line_items[0][quantity]': '1',
    mode: 'payment',
    expires_at: String(expiresAt),
    success_url: `${origin}/student/payments?stripe=success&invoice=${invoice._id}`,
    cancel_url: `${origin}/student/payments?stripe=cancel`,
    'metadata[invoiceId]': String(invoice._id),
    'metadata[studentId]': String(req.user._id),
  });
  invoice.stripeSessionId = session.id;
  invoice.stripeExpectedAmount = amount;
  invoice.stripeExpectedCurrency = currency;
  invoice.stripeCheckoutExpiresAt = new Date(expiresAt * 1000);
  invoice.stripeCheckoutUrl = session.url;
  await invoice.save();
  res.json({ url: session.url, sessionId: session.id });
  }, { ms: 60000 });
}));

// Stripe sends raw body — must be registered BEFORE express.json() parses it.
// Since app.js applies express.json() globally before this router, we parse
// via the raw body stored by express. As a workaround, we collect the raw
// body using a dedicated middleware registered here before the route.
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  if (!sig) return res.status(400).json({ message: 'Missing signature' });
  let event;
  try {
    event = verifyStripeSignature(req.rawBody || req.body, sig);
  } catch {
    return res.status(400).json({ message: 'Invalid signature' });
  }
  if (!event) return res.status(400).json({ message: 'Signature verification failed' });

  if (event.type === 'checkout.session.completed' && event.data?.object?.payment_status === 'paid') {
    const meta = event.data.object.metadata;
    const invoiceId = meta?.invoiceId;
    const studentId = meta?.studentId;
    if (invoiceId && studentId) {
      try {
        const updated = await Invoice.findOneAndUpdate(
          { _id: invoiceId, student: studentId, status: 'unpaid', stripeSessionId: event.data.object.id,
            stripeExpectedAmount: event.data.object.amount_total, stripeExpectedCurrency: event.data.object.currency },
          { $set: { status: 'paid', reviewedAt: new Date() }, $unset: { stripeCheckoutUrl: 1, stripeCheckoutExpiresAt: 1 } },
          { new: true }
        );
        if (updated) {
          await Notification.create({ user: studentId, title: 'تم استلام الدفع بنجاح', message: `تم تأكيد دفع الفاتورة ${updated.invoiceNumber || ''}.`, type: 'success', link: '/student/payments' });
          sendPushToUser(studentId, { title: 'تم استلام الدفع', body: 'تم تأكيد دفعتك بنجاح.', link: '/student/payments' }).catch(() => {});
        }
      } catch (err) {
        console.error('[Stripe webhook] failed to mark invoice paid:', err.message);
        return res.status(500).json({ message: 'Payment update failed; retry delivery' });
      }
    }
  }
  res.json({ received: true });
});

module.exports = router;
