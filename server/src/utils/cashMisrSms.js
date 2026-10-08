/**
 * CashMisr SMS Gateway integration.
 * Drop-in replacement for whatsappOtp.js — same exported interface.
 *
 * Required environment variables (set on Render):
 *   CASHMISR_API_URL   — the API endpoint from your CashMisr dashboard
 *   CASHMISR_USERNAME  — your CashMisr account username
 *   CASHMISR_PASSWORD  — your CashMisr account password
 *   CASHMISR_SENDER_ID — the approved sender name (e.g. StudyBirds)
 */

const { createHmac, randomInt } = require("node:crypto");
const https = require("node:https");
const http  = require("node:http");

const cfg = () => ({
  url:      String(process.env.CASHMISR_API_URL   || "").trim(),
  username: String(process.env.CASHMISR_USERNAME   || "").trim(),
  password: String(process.env.CASHMISR_PASSWORD   || "").trim(),
  sender:   String(process.env.CASHMISR_SENDER_ID  || "StudyBirds").trim(),
});

/** Returns true when all required env vars are present. */
function ready() {
  const { url, username, password } = cfg();
  return Boolean(url && username && password);
}

/** Generates a 6-digit OTP string. */
function generate() {
  return randomInt(100000, 1000000).toString();
}

/**
 * HMAC-SHA256 of "sms-otp:<phone>:<code>" using JWT_SECRET.
 * Used to store and verify OTPs without saving plaintext codes.
 */
function hash(phone, code) {
  return createHmac("sha256", process.env.JWT_SECRET || "dev")
    .update(`sms-otp:${phone}:${code}`)
    .digest("hex");
}

/**
 * Sends an SMS OTP via CashMisr API.
 * Throws on HTTP error or API-level failure.
 *
 * @param {string} phone — E.164 number, e.g. +201012345678
 * @param {string} code  — 6-digit OTP
 */
async function send(phone, code) {
  const { url, username, password, sender } = cfg();
  if (!url || !username || !password) {
    throw new Error("CashMisr SMS is not configured on the server.");
  }

  const message = `رمز التحقق من Study Birds: ${code}\nصالح 5 دقائق. لا تشاركه مع أحد.`;

  // Build query-string params (standard for most Egyptian SMS APIs).
  // Adjust key names below if CashMisr uses different parameter names.
  const params = new URLSearchParams({
    username,
    password,
    sender,
    mobile:  phone,
    message,
    // language: "2", // uncomment if API requires Arabic=2 / English=1
  });

  const parsedUrl = new URL(`${url}?${params.toString()}`);
  const transport = parsedUrl.protocol === "https:" ? https : http;

  return new Promise((resolve, reject) => {
    const req = transport.get(parsedUrl.toString(), (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => { body += chunk; });
      res.on("end", () => {
        // CashMisr typically returns a JSON object or a plain status string.
        // A 2xx HTTP code with a non-error body is treated as success.
        if (res.statusCode >= 200 && res.statusCode < 300) {
          // Some gateways signal failure inside the body even on HTTP 200.
          // Common error indicators: body starts with "-" or contains "error".
          const lower = body.trim().toLowerCase();
          if (lower.startsWith("-") || lower.includes('"error"') || lower.includes("error:")) {
            console.error("[CashMisr] API error body:", body.trim());
            reject(new Error(`CashMisr error: ${body.trim()}`));
          } else {
            console.log("[CashMisr] SMS sent to", phone, "| response:", body.trim());
            resolve({ sent: true, response: body.trim() });
          }
        } else {
          console.error("[CashMisr] HTTP", res.statusCode, body.trim());
          reject(new Error(`CashMisr HTTP ${res.statusCode}: ${body.trim()}`));
        }
      });
    });

    req.on("error", (err) => {
      console.error("[CashMisr] network error:", err.message);
      reject(new Error(`تعذر الاتصال بخدمة الرسائل: ${err.message}`));
    });

    req.setTimeout(15000, () => {
      req.destroy();
      reject(new Error("انتهت مهلة الاتصال بخدمة الرسائل"));
    });
  });
}

module.exports = { ready, generate, hash, send };
