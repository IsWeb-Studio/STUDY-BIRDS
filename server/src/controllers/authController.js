const { sendCode, consume } = require('../utils/mobileEmailCodes');
const { randomBytes, createHash } = require('node:crypto');
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const { OAuth2Client } = require("google-auth-library");
const asyncHandler = require("../utils/asyncHandler");
const generateToken = require("../utils/generateToken");
const { recordReferralSignup } = require("../utils/studentWallet");
const { Challenge } = require('../models/IdentityCredential');

const googleClient = new OAuth2Client();

const serializeUser = (user) => ({
  _id: user._id,
  name: user.name,
  email: user.email,
  role: user.role,
  avatar: user.avatar,
  authProvider: user.authProvider,
  emailVerified: user.emailVerified,
  verifiedPhone: user.verifiedPhone || null,
  // NEW — always present but null/empty for existing student/admin/partner
  // accounts, so no existing consumer (website included) is affected.
  employeeRole: user.employeeRole || null,
  permissions: user.permissions || [],
  linkedUniversity: user.linkedUniversity || null,
});

const ensureStudentProfile = async (userId) => {
  const existingProfile = await StudentProfile.findOne({ user: userId });
  if (!existingProfile) {
    await StudentProfile.create({ user: userId });
  }
};

const register = asyncHandler(async (req, res) => {
  const { name, email, password } = req.body;
  const normalizedEmail = String(email || "").toLowerCase().trim();

  if (!String(name || "").trim() || !normalizedEmail || !password) {
    res.status(400);
    throw new Error("Name, email, and password are required");
  }

  // Agents (partner) can self-register; universities and employees must be admin-created.
  const allowedSelfRegisterRoles = ["student", "parent", "partner"];
  const requestedRole = req.body.role;
  const role = allowedSelfRegisterRoles.includes(requestedRole) ? requestedRole : "student";

  const existingUser = await User.findOne({ email: normalizedEmail });
  if (existingUser) {
    res.status(400);
    throw new Error("Email already in use");
  }

  const user = await User.create({
    name: String(name || "").trim(),
    email: normalizedEmail,
    password,
    role,
    authProvider: "local",
  });

  if (role === "student") await ensureStudentProfile(user._id);
  if (typeof req.body.referralCode === "string" && req.body.referralCode.trim()) {
    await recordReferralSignup(user._id, req.body.referralCode).catch((error) => console.error("Referral signup failed", error.message));
  }

  const tokens = await issueTokenPair(user);
  res.status(201).json({ ...tokens, user: serializeUser(user) });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = String(email || "").toLowerCase().trim();

  if (!normalizedEmail || !password) {
    res.status(400);
    throw new Error("Email and password are required");
  }

  const user = await User.findOne({ email: normalizedEmail });
  if (!user || !(await user.comparePassword(password))) {
    res.status(401);
    throw new Error("Invalid credentials");
  }

  if (!user.isActive) {
    res.status(403);
    throw new Error("This account has been deactivated by an administrator");
  }

  if (user.twoFactorEnabled) {
    if (!req.body.twoFactorCode) {
      await sendCode(user, 'login', res);
      return res.status(428).json({ message: 'أدخل رمز التحقق المرسل إلى بريدك.', requiresTwoFactor: true });
    }
    await consume(user, 'login', req.body.twoFactorCode, res);
  }

  user.lastLoginAt = new Date();
  await user.save();

  const tokens = await issueTokenPair(user);
  res.json({ ...tokens, user: serializeUser(user) });
});

const googleLogin = asyncHandler(async (req, res) => {
  const { credential } = req.body;
  const googleClientIds = String(process.env.GOOGLE_CLIENT_ID || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (!googleClientIds.length) {
    res.status(503);
    throw new Error("Google sign-in is not configured");
  }

  if (!credential) {
    res.status(400);
    throw new Error("Google credential is required");
  }

  const ticket = await googleClient.verifyIdToken({
    idToken: credential,
    audience: googleClientIds,
  });

  const payload = ticket.getPayload();

  if (!payload?.sub || !payload.email || !payload.email_verified) {
    res.status(401);
    throw new Error("Unable to verify Google account");
  }

  const normalizedEmail = payload.email.toLowerCase().trim();
  let user = await User.findOne({
    $or: [{ googleId: payload.sub }, { email: normalizedEmail }],
  });

  if (user?.twoFactorEnabled) {
    res.status(403);
    throw new Error('استخدم البريد وكلمة المرور ورمز التحقق لتسجيل الدخول إلى هذا الحساب.');
  }

  if (!user) {
    user = await User.create({
      name: payload.name || normalizedEmail.split("@")[0],
      email: normalizedEmail,
      googleId: payload.sub,
      authProvider: "google",
      emailVerified: true,
      avatar: payload.picture,
      role: "student",
    });

    await ensureStudentProfile(user._id);
  } else {
    if (!user.isActive) {
      res.status(403);
      throw new Error("This account has been deactivated by an administrator");
    }

    user.googleId = user.googleId || payload.sub;
    user.emailVerified = true;

    if (!user.avatar && payload.picture) {
      user.avatar = payload.picture;
    }

    if (!user.authProvider) {
      user.authProvider = user.password ? "local" : "google";
    }
  }

  user.lastLoginAt = new Date();
  await user.save();

  if (user.role === "student") {
    await ensureStudentProfile(user._id);
  }

  const tokens = await issueTokenPair(user);
  res.json({ ...tokens, user: serializeUser(user) });
});

const me = asyncHandler(async (req, res) => {
  const profile =
    req.user.role === "student" || req.user.role === "partner"
      ? await StudentProfile.findOne({ user: req.user._id })
      : null;

  // NEW — additive extra context for the two new roles. Neither branch
  // touches the student/partner path above.
  let parentLinkedChildrenCount = null;
  let university = null;

  if (req.user.role === "parent") {
    const ParentLink = require("../models/ParentLink");
    parentLinkedChildrenCount = await ParentLink.countDocuments({
      parent: req.user._id,
      status: "approved",
    });
  }

  if (req.user.role === "university" && req.user.linkedUniversity) {
    const University = require("../models/University");
    university = await University.findById(req.user.linkedUniversity).lean();
  }

  res.json({
    user: req.user,
    profile,
    parentLinkedChildrenCount,
    university,
  });
});

const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!newPassword) {
    res.status(400);
    throw new Error("New password is required");
  }

  if (String(newPassword).length < 6) {
    res.status(400);
    throw new Error("New password must be at least 6 characters");
  }

  const user = await User.findById(req.user._id);

  if (!user) {
    res.status(404);
    throw new Error("User not found");
  }

  if (user.password && !currentPassword) {
    res.status(400);
    throw new Error("Current password is required");
  }

  if (user.password && !(await user.comparePassword(currentPassword))) {
    res.status(400);
    throw new Error("Current password is incorrect");
  }

  user.password = newPassword;
  await user.save();

  res.json({ message: "Password updated successfully" });
});

const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

function makeRefreshToken() {
  return randomBytes(32).toString('hex');
}

function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

async function issueTokenPair(user) {
  const refresh = makeRefreshToken();
  user.refreshTokenHash = hashToken(refresh);
  user.refreshTokenExpiry = new Date(Date.now() + REFRESH_TTL_MS);
  await user.save();
  return { token: generateToken(user._id, user.tokenVersion), refreshToken: refresh };
}

const refresh = asyncHandler(async (req, res) => {
  const raw = req.body.refreshToken;
  if (typeof raw !== 'string' || !raw.trim()) {
    res.status(400);
    throw new Error('refreshToken required');
  }
  const hash = hashToken(raw.trim());
  const user = await User.findOne({ refreshTokenHash: hash, refreshTokenExpiry: { $gt: new Date() } }).select('+refreshTokenHash');
  if (!user || !user.isActive) {
    res.status(401);
    throw new Error('Invalid or expired refresh token');
  }
  const tokens = await issueTokenPair(user);
  res.json({ ...tokens, user: serializeUser(user) });
});

const logout = asyncHandler(async (req, res) => {
  const raw = req.body.refreshToken;
  if (typeof raw === 'string' && raw.trim()) {
    await User.updateOne({ refreshTokenHash: hashToken(raw.trim()) }, { $unset: { refreshTokenHash: 1, refreshTokenExpiry: 1 } });
  }
  res.json({ ok: true });
});

// #6: Phone OTP login — step 1: request OTP via Twilio Verify
const requestOtp = asyncHandler(async (req, res) => {
  const twilioReady = () => process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN && process.env.TWILIO_VERIFY_SERVICE_SID;
  if (!twilioReady()) return res.status(503).json({ message: 'Phone login is not configured' });
  const phone = String(req.body.phone || '').trim();
  if (!/^\+[1-9]\d{7,14}$/.test(phone)) return res.status(400).json({ message: 'أدخل رقمًا دوليًا يبدأ بـ + ورمز الدولة' });
  const key = `otp-login:${phone}`;
  const existing = await Challenge.findOne({ key });
  if (existing && Date.now() - existing.createdAt.getTime() < 60000) return res.status(429).json({ message: 'انتظر دقيقة قبل طلب رمز جديد' });
  await Challenge.deleteOne({ key });
  const twilioRes = await fetch(`https://verify.twilio.com/v2/Services/${process.env.TWILIO_VERIFY_SERVICE_SID}/Verifications`, {
    method: 'POST',
    headers: { Authorization: 'Basic ' + Buffer.from(`${process.env.TWILIO_ACCOUNT_SID}:${process.env.TWILIO_AUTH_TOKEN}`).toString('base64'), 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ To: phone, Channel: 'whatsapp' }),
    signal: AbortSignal.timeout(15000),
  });
  if (!twilioRes.ok) {
    const body = await twilioRes.json().catch(() => ({}));
    console.error('[OTP] Twilio error:', twilioRes.status, JSON.stringify(body));
    return res.status(502).json({ message: body.message || 'تعذر إرسال الرمز. حاول مجدداً.' });
  }
  await Challenge.create({ key, value: phone, createdAt: new Date() });
  res.json({ sent: true });
});

// #6: Phone OTP login — step 2: verify OTP + issue JWT
const verifyOtp = asyncHandler(async (req, res) => {
  const twilioReady = () => process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN && process.env.TWILIO_VERIFY_SERVICE_SID;
  if (!twilioReady()) return res.status(503).json({ message: 'Phone login is not configured' });
  const phone = String(req.body.phone || '').trim();
  const code = String(req.body.code || '').trim();
  if (!/^\+[1-9]\d{7,14}$/.test(phone) || !/^\d{4,10}$/.test(code)) return res.status(400).json({ message: 'رقم أو رمز غير صالح' });
  const result = await fetch(`https://verify.twilio.com/v2/Services/${process.env.TWILIO_VERIFY_SERVICE_SID}/VerificationCheck`, {
    method: 'POST',
    headers: { Authorization: 'Basic ' + Buffer.from(`${process.env.TWILIO_ACCOUNT_SID}:${process.env.TWILIO_AUTH_TOKEN}`).toString('base64'), 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ To: phone, Code: code }),
    signal: AbortSignal.timeout(15000),
  }).then(r => r.json());
  if (result.status !== 'approved') return res.status(401).json({ message: 'رمز التحقق غير صحيح أو منتهي الصلاحية' });
  await Challenge.deleteOne({ key: `otp-login:${phone}` });
  let user = await User.findOne({ verifiedPhone: phone });
  if (!user) {
    user = await User.create({ name: phone, email: `${phone.replace('+', '')}@phone.studybirds.net`, verifiedPhone: phone, authProvider: 'phone', role: 'student' });
    await ensureStudentProfile(user._id);
  }
  if (!user.isActive) return res.status(403).json({ message: 'الحساب موقوف' });
  user.verifiedPhone = phone;
  user.lastLoginAt = new Date();
  await user.save();
  const tokens = await issueTokenPair(user);
  res.json({ ...tokens, user: serializeUser(user) });
});

module.exports = {
  serializeUser,
  ensureStudentProfile,
  issueTokenPair,
  register,
  login,
  googleLogin,
  requestOtp,
  verifyOtp,
  me,
  changePassword,
  refresh,
  logout,
};
