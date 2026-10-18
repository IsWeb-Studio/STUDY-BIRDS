const { sendCode, consume } = require('../utils/mobileEmailCodes');
const { passwordError } = require('../utils/passwordPolicy');
const { randomBytes, createHash } = require('node:crypto');
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const { OAuth2Client } = require("google-auth-library");
const asyncHandler = require("../utils/asyncHandler");
const generateToken = require("../utils/generateToken");
const { recordReferralSignup } = require("../utils/studentWallet");
const { Challenge } = require('../models/IdentityCredential');
const sms = require('../utils/cashMisrSms');

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
  hasPassword: Boolean(user.password),
  employeeRole: user.employeeRole || null,
  crmLinked: Boolean(user.crmIdentity?.companyId),
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
  if (typeof name !== 'string' || name.trim().length > 120 || typeof email !== 'string' ||
      email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) ||
      typeof password !== 'string' || password.length < 8 || Buffer.byteLength(password, 'utf8') > 72) {
    res.status(400);
    throw new Error('أدخل اسمًا وبريدًا صحيحين وكلمة مرور من 8 أحرف على الأقل. إذا كانت كلمة المرور طويلة جدًا، استخدم واحدة أقصر.');
  }
  const normalizedEmail = String(email || "").toLowerCase().trim();

  if (!String(name || "").trim() || !normalizedEmail || !password) {
    res.status(400);
    throw new Error("Name, email, and password are required");
  }

  // Agents (partner) can self-register; universities and employees must be admin-created.
  const weakPassword = passwordError(password);
  if (weakPassword) { res.status(400); throw new Error(weakPassword); }
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
  if (typeof email !== 'string' || email.length > 254 || typeof password !== 'string' || password.length > 200) {
    res.status(400); throw new Error('Email and password are required');
  }
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
  // Accept the original mobile challenge field during rolling app updates.
  const emailCode = req.body.emailCode ?? req.body.twoFactorCode;
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

    if (!user.avatar && payload.picture) {
      user.avatar = payload.picture;
    }

    if (!user.authProvider) {
      user.authProvider = user.password ? "local" : "google";
    }

    // Returning Google users are implicitly verified — Google itself confirmed
    // email_verified. Auto-set so they are never asked for a code again.
    if (!user.emailVerified) {
      user.emailVerified = true;
    }
  }

  // Persist Google linkage before any challenge check.
  await user.save();

  if (!user.emailVerified) {
    // NEW user: one-time email verification before they can set a password.
    if (!emailCode) {
      await sendCode(user, 'login', res);
      return res.status(428).json({
        message: 'أدخل رمز التأكيد المرسل إلى بريد حسابك في Google.',
        requiresEmailVerification: true,
      });
    }
    await consume(user, 'login', emailCode, res);
    user.emailVerified = true;
  } else if (user.twoFactorEnabled) {
    // RETURNING user with 2FA: require code on every login.
    if (!emailCode) {
      await sendCode(user, 'login', res);
      return res.status(428).json({
        message: 'أدخل رمز التحقق المرسل إلى بريدك.',
        requiresTwoFactor: true,
      });
    }
    await consume(user, 'login', emailCode, res);
  }
  user.lastLoginAt = new Date();
  await user.save();

  if (user.role === "student") {
    await ensureStudentProfile(user._id);
  }

  const tokens = await issueTokenPair(user, { googlePasswordVerifiedAt: Date.now() });
  res.json({ ...tokens, user: serializeUser(user) });
});

const me = asyncHandler(async (req, res) => {
  const account = await User.findById(req.user._id).select("password");
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
    user: { ...req.user.toObject(), hasPassword: Boolean(account?.password) },
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

  if (typeof newPassword !== "string" || newPassword.length < 8) {
    res.status(400);
    throw new Error("New password must be at least 8 characters");
  }
  if (Buffer.byteLength(newPassword, 'utf8') > 72) {
    res.status(400); throw new Error('كلمة المرور طويلة جدًا. استخدم كلمة مرور أقصر.');
  }
  if (currentPassword != null && (typeof currentPassword !== 'string' || currentPassword.length > 200)) {
    res.status(400); throw new Error('راجع كلمة المرور الحالية وحاول مجددًا.');
  }

  const weakPassword = passwordError(newPassword);
  if (weakPassword) { res.status(400); throw new Error(weakPassword); }

  const user = await User.findById(req.user._id);

  if (!user) {
    res.status(404);
    throw new Error("User not found");
  }

  const verifiedAt = req.googlePasswordVerifiedAt;
  const googleVerified = typeof verifiedAt === 'number' &&
    verifiedAt <= Date.now() && Date.now() - verifiedAt < 10 * 60 * 1000;
  if (req.body.passwordSetup === true && !googleVerified) {
    res.status(400);
    throw new Error('انتهى تأكيد حساب Google أو لم يصل إلى السيرفر. أعد الدخول بجوجل وأكد الكود، ثم احفظ كلمة المرور.');
  }
  if (user.password && !currentPassword && !googleVerified) {
    res.status(400);
    throw new Error("Current password is required");
  }

  if (user.password && !googleVerified && !(await user.comparePassword(currentPassword))) {
    res.status(400);
    throw new Error("Current password is incorrect");
  }

  user.password = newPassword;
  user.passwordChangedAt = new Date();
  // Atomic increment: concurrent password changes must never reuse a version.
  user.$inc('tokenVersion', 1);
  user.refreshTokenHash = undefined;
  user.refreshTokenExpiry = undefined;
  await user.save();

  // Replace this client's credentials; every previously issued JWT is invalid.
  const tokens = await issueTokenPair(user);
  res.json({ message: "Password updated successfully", ...tokens, user: serializeUser(user) });
});

const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

function makeRefreshToken() {
  return randomBytes(32).toString('hex');
}

function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

async function issueTokenPair(user, claims = {}) {
  const refresh = makeRefreshToken();
  // Do not resurrect credentials after concurrent logout/password revocation.
  const version = user.tokenVersion || 0;
  const account = await User.findOneAndUpdate({
    _id: user._id, isActive: true,
    $or: [{ tokenVersion: version }, ...(version === 0 ? [{ tokenVersion: { $exists: false } }] : [])],
  }, { $set: {
    refreshTokenHash: hashToken(refresh),
    refreshTokenExpiry: new Date(Date.now() + REFRESH_TTL_MS),
  } }, { new: true });
  if (!account) {
    const error = new Error('Session changed. Please sign in again.');
    error.statusCode = 401;
    throw error;
  }
  return { token: generateToken(account._id, account.tokenVersion, claims), refreshToken: refresh };
}

const refresh = asyncHandler(async (req, res) => {
  const raw = req.body.refreshToken;
  if (typeof raw !== 'string' || !/^[a-f0-9]{64}$/.test(raw.trim())) {
    res.status(400);
    throw new Error('Invalid refresh token');
  }
  const nextRefresh = makeRefreshToken();
  // Compare-and-swap consumes the old token exactly once, even concurrently.
  const user = await User.findOneAndUpdate({
    refreshTokenHash: hashToken(raw.trim()),
    refreshTokenExpiry: { $gt: new Date() },
    isActive: true,
  }, { $set: {
    refreshTokenHash: hashToken(nextRefresh),
    refreshTokenExpiry: new Date(Date.now() + REFRESH_TTL_MS),
  } }, { new: true });
  if (!user) {
    res.status(401);
    throw new Error('Invalid or expired refresh token');
  }
  res.json({
    token: generateToken(user._id, user.tokenVersion),
    refreshToken: nextRefresh,
    user: serializeUser(user),
  });
});

const logout = asyncHandler(async (req, res) => {
  const raw = req.body.refreshToken;
  // Web clients authenticate with protect; offline mobile revocations may carry
  // only a refresh token. Scope the update to the supplied credential's owner.
  let filter;
  if (req.user) {
    const version = req.user.tokenVersion || 0;
    filter = { _id: req.user._id,
      $or: [{ tokenVersion: version }, ...(version === 0 ? [{ tokenVersion: { $exists: false } }] : [])] };
  } else if (typeof raw === 'string' && /^[a-f0-9]{64}$/.test(raw.trim())) {
    filter = { refreshTokenHash: hashToken(raw.trim()), refreshTokenExpiry: { $gt: new Date() } };
  } else {
    res.status(401);
    throw new Error('A valid session is required');
  }
  const result = await User.updateOne(filter, {
    $inc: { tokenVersion: 1 },
    $unset: { refreshTokenHash: 1, refreshTokenExpiry: 1 },
  });
  if (!result.matchedCount) {
    res.status(401);
    throw new Error('Invalid or expired session');
  }
  res.json({ ok: true });
});

// Phone OTP login — step 1: send code via SMS (CashMisr)
const requestOtp = asyncHandler(async (req, res) => {
  if (!sms.ready()) return res.status(503).json({ message: 'Phone login is not configured' });
  const phone = String(req.body.phone || '').trim();
  if (!/^\+[1-9]\d{7,14}$/.test(phone)) return res.status(400).json({ message: 'أدخل رقمًا دوليًا يبدأ بـ + ورمز الدولة' });
  const account = await User.findOne({ verifiedPhone: phone });
  if (account?.twoFactorEnabled) return res.status(403).json({
    message: 'Use your password or identity provider and complete two-factor verification.',
    requiresTwoFactor: true,
  });
  const key = `otp-login:${phone}`;
  const existing = await Challenge.findOne({ key, purpose: 'otp-login', expiresAt: { $gt: new Date(Date.now() + 9 * 60 * 1000) } });
  if (existing) return res.status(429).json({ message: 'انتظر دقيقة قبل طلب رمز جديد' });
  await Challenge.deleteOne({ key });
  const code = sms.generate();
  try {
    await sms.send(phone, code);
  } catch (e) {
    return res.status(502).json({ message: e.message || 'تعذر إرسال الرمز. حاول مجدداً.' });
  }
  await Challenge.create({ key, purpose: 'otp-login', value: sms.hash(phone, code), expiresAt: new Date(Date.now() + 10 * 60 * 1000) });
  res.json({ sent: true });
});

// Phone OTP login — step 2: verify code + issue JWT
const verifyOtp = asyncHandler(async (req, res) => {
  if (!sms.ready()) return res.status(503).json({ message: 'Phone login is not configured' });
  const phone = String(req.body.phone || '').trim();
  const code  = String(req.body.code  || '').trim();
  if (!/^\+[1-9]\d{7,14}$/.test(phone) || !/^\d{6}$/.test(code)) return res.status(400).json({ message: 'رقم أو رمز غير صالح' });
  const pending = await Challenge.findOneAndDelete({ key: `otp-login:${phone}`, purpose: 'otp-login', expiresAt: { $gt: new Date() } });
  if (!pending || pending.value !== sms.hash(phone, code)) return res.status(401).json({ message: 'رمز التحقق غير صحيح أو منتهي الصلاحية' });
  let user = await User.findOne({ verifiedPhone: phone });
  if (!user) {
    user = await User.create({ name: phone, email: `${phone.replace('+', '')}@phone.studybirds.net`, verifiedPhone: phone, authProvider: 'phone', role: 'student' });
    await ensureStudentProfile(user._id);
  }
  if (!user.isActive) return res.status(403).json({ message: 'الحساب موقوف' });
  if (user.twoFactorEnabled) return res.status(403).json({
    message: 'Use your password or identity provider and complete two-factor verification.',
    requiresTwoFactor: true,
  });
  user.verifiedPhone = phone;
  user.lastLoginAt = new Date();
  await user.save();
  const tokens = await issueTokenPair(user);
  res.json({ ...tokens, user: serializeUser(user) });
});

// Email OTP login — step 1: send code via Brevo
const requestEmailOtp = asyncHandler(async (req, res) => {
  const { isMailerConfigured } = require('../utils/mailer');
  if (!isMailerConfigured()) { res.status(503); throw new Error('إرسال البريد غير مهيأ على السيرفر'); }
  const email = String(req.body.email || '').toLowerCase().trim();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    res.status(400); throw new Error('أدخل بريدًا إلكترونيًا صحيحًا');
  }
  const user = await User.findOne({ email, isActive: true });
  // Email OTP is an explicit alternate sign-in method for previously verified
  // accounts. It must never bootstrap verification or register a new account.
  if (!user?.emailVerified) return res.status(403).json({
    message: 'الدخول برمز البريد متاح فقط لحساب فعّال وبريد موثّق مسبقًا. سجّل الدخول بالطريقة الأساسية وأكمل توثيق البريد أولًا.',
  });
  await sendCode(user, 'emaillogin', res);
  res.json({ sent: true });
});

// Email OTP login — step 2: verify code + issue JWT
const verifyEmailOtp = asyncHandler(async (req, res) => {
  const email = String(req.body.email || '').toLowerCase().trim();
  const code  = String(req.body.code  || '').trim();
  if (!email || !/^\d{6}$/.test(code)) {
    res.status(400); throw new Error('بريد إلكتروني أو رمز غير صحيح');
  }
  const user = await User.findOne({ email, isActive: true });
  // Recheck eligibility at redemption: verification/activation may have changed
  // since the code was requested. The code remains single-use and short-lived.
  if (!user?.emailVerified) return res.status(403).json({
    message: 'الدخول برمز البريد متاح فقط لحساب فعّال وبريد موثّق مسبقًا. سجّل الدخول بالطريقة الأساسية وأكمل توثيق البريد أولًا.',
  });
  await consume(user, 'emaillogin', code, res);
  if (user.role === 'student') await ensureStudentProfile(user._id);
  user.lastLoginAt = new Date();
  await user.save();
  const tokens = await issueTokenPair(user);
  res.json({ ...tokens, user: serializeUser(user) });
});

const deleteAccount = asyncHandler(async (req, res) => {
  const { password, emailCode } = req.body;

  const user = await User.findById(req.user._id);
  if (!user) {
    res.status(404);
    throw new Error('User not found');
  }

  // Local-auth users must verify their password; Google/phone users have no password
  if (user.password) {
    if (!password) {
      res.status(400);
      throw new Error('كلمة المرور مطلوبة');
    }
    if (!(await user.comparePassword(password))) {
      res.status(401);
      throw new Error('كلمة المرور غير صحيحة');
    }
  } else {
    await consume(user, 'delete-account', emailCode, res);
  }

  await require('../utils/accountDeletion').deleteAccountData(user);

  res.json({ ok: true });
});

const requestAccountDeletion = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id);
  if (!user) return res.sendStatus(404);
  if (!user.password) await sendCode(user, 'delete-account', res);
  res.json({ requiresPassword: Boolean(user.password), sent: !user.password });
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
  requestEmailOtp,
  verifyEmailOtp,
  me,
  changePassword,
  refresh,
  logout,
  deleteAccount,
  requestAccountDeletion,
};
