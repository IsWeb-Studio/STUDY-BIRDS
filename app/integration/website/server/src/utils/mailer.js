const nodemailer = require('nodemailer');

/**
 * Returns true when all required SMTP environment variables are present.
 * Used as a guard before attempting to send so callers can return 503
 * instead of crashing when email is not configured.
 */
function isMailerConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

let _transport = null;

function getTransport() {
  if (_transport) return _transport;
  _transport = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT) || 587,
    secure: Number(process.env.SMTP_PORT) === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
  return _transport;
}

/**
 * Sends a plain-text email.
 * @param {{ to: string, subject: string, text: string }} options
 */
async function sendContactEmail({ to, subject, text }) {
  const from = process.env.EMAIL_FROM || process.env.SMTP_USER;
  await getTransport().sendMail({ from, to, subject, text });
}

module.exports = { isMailerConfigured, sendContactEmail };
