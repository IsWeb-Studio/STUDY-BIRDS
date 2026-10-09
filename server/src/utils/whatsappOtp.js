const { createHmac, randomInt } = require('node:crypto');

const ready = () =>
  Boolean(process.env.TWILIO_ACCOUNT_SID &&
          process.env.TWILIO_AUTH_TOKEN &&
          process.env.TWILIO_WHATSAPP_FROM);

function generate() {
  return randomInt(100000, 1000000).toString();
}

function hash(phone, code) {
  return createHmac('sha256', process.env.JWT_SECRET || 'dev')
    .update(`wa-otp:${phone}:${code}`)
    .digest('hex');
}

async function send(phone, code) {
  const from = `whatsapp:${process.env.TWILIO_WHATSAPP_FROM}`;
  const to   = `whatsapp:${phone}`;
  const body = `رمز التحقق من Study Birds: *${code}*\n\nصالح 10 دقائق. لا تشاركه مع أحد.`;
  const auth = Buffer.from(
    `${process.env.TWILIO_ACCOUNT_SID}:${process.env.TWILIO_AUTH_TOKEN}`
  ).toString('base64');

  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${process.env.TWILIO_ACCOUNT_SID}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ From: from, To: to, Body: body }),
      signal: AbortSignal.timeout(15000),
    }
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    console.error('[WhatsApp OTP] error:', res.status, JSON.stringify(err));
    throw Object.assign(new Error(err.message || 'تعذر إرسال رمز التحقق'), { twilioCode: err.code });
  }
  return res.json();
}

module.exports = { ready, generate, hash, send };
