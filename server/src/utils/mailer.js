const https     = require("https");
const nodemailer = require("nodemailer");

// ─── Brevo REST API (primary) ────────────────────────────────────────────────
const BREVO_API_KEY      = String(process.env.BREVO_API_KEY      || "").trim();
const BREVO_SENDER_EMAIL = String(process.env.BREVO_SENDER_EMAIL || process.env.SMTP_FROM || "").trim();
const BREVO_SENDER_NAME  = String(process.env.BREVO_SENDER_NAME  || "Study Birds").trim();

// ─── SMTP fallback ────────────────────────────────────────────────────────────
const SMTP_HOST = String(process.env.SMTP_HOST || "").trim();
const SMTP_PORT = Number(process.env.SMTP_PORT || 587);
const SMTP_USER = String(process.env.SMTP_USER || "").trim();
const SMTP_PASS = String(process.env.SMTP_PASS || "").trim();
const SMTP_FROM = String(process.env.SMTP_FROM || SMTP_USER || "").trim();

const isBrevoConfigured = () => Boolean(BREVO_API_KEY && BREVO_SENDER_EMAIL);
const isSmtpConfigured  = () => Boolean(SMTP_HOST && SMTP_PORT && SMTP_USER && SMTP_PASS && SMTP_FROM);
const isMailerConfigured = () => isBrevoConfigured() || isSmtpConfigured();

// ─── Brevo transactional email via REST API ───────────────────────────────────
function _sendWithBrevo({ to, replyTo, subject, text, html }) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      sender:      { name: BREVO_SENDER_NAME, email: BREVO_SENDER_EMAIL },
      to:          [{ email: to }],
      ...(replyTo ? { replyTo: { email: replyTo } } : {}),
      subject,
      ...(text ? { textContent: text } : {}),
      ...(html ? { htmlContent: html } : {}),
    });

    const req = https.request(
      {
        hostname: "api.brevo.com",
        path:     "/v3/smtp/email",
        method:   "POST",
        headers:  {
          "accept":         "application/json",
          "api-key":        BREVO_API_KEY,
          "content-type":   "application/json",
          "content-length": Buffer.byteLength(payload),
        },
      },
      (res) => {
        let body = "";
        res.on("data", (chunk) => { body += chunk; });
        res.on("end", () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try { resolve(JSON.parse(body)); } catch { resolve({}); }
          } else {
            reject(new Error(`Brevo API error ${res.statusCode}: ${body}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

// ─── SMTP fallback via nodemailer ─────────────────────────────────────────────
let _smtpTransporter = null;
function _getSmtpTransporter() {
  if (!_smtpTransporter) {
    _smtpTransporter = nodemailer.createTransport({
      host:   SMTP_HOST,
      port:   SMTP_PORT,
      secure: SMTP_PORT === 465,
      auth:   { user: SMTP_USER, pass: SMTP_PASS },
    });
  }
  return _smtpTransporter;
}

// ─── Public API ───────────────────────────────────────────────────────────────
const sendContactEmail = async ({ to, replyTo, subject, text, html }) => {
  if (!isMailerConfigured()) {
    throw new Error("Email delivery is not configured on the server");
  }
  if (isBrevoConfigured()) {
    return _sendWithBrevo({ to, replyTo, subject, text, html });
  }
  return _getSmtpTransporter().sendMail({
    from: SMTP_FROM, to, replyTo, subject, text, html,
  });
};

module.exports = { isMailerConfigured, sendContactEmail };
