const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const { OAuth2Client } = require("google-auth-library");
const asyncHandler = require("../utils/asyncHandler");
const generateToken = require("../utils/generateToken");
const { sendCode, consume } = require('../utils/mobileEmailCodes');

const googleClient = new OAuth2Client();

const serializeUser = (user) => ({
  _id: user._id,
  name: user.name,
  email: user.email,
  role: user.role,
  avatar: user.avatar,
  authProvider: user.authProvider,
  hasPassword: Boolean(user.password),
  emailVerified: user.emailVerified,
});

const ensureStudentProfile = async (userId) => {
  const existingProfile = await StudentProfile.findOne({ user: userId });
  if (!existingProfile) {
    await StudentProfile.create({ user: userId });
  }
};

const register = asyncHandler(async (req, res) => {
  const { name, email, password } = req.body;
  const role = req.body.role || "student";
  if (!["student", "parent"].includes(role)) {
    res.status(403);
    throw new Error("This account type must be created by an administrator");
  }
  if (typeof password !== "string" || password.length < 8) {
    res.status(400);
    throw new Error("Password must be at least 8 characters");
  }
  const normalizedEmail = String(email || "").toLowerCase().trim();

  if (!String(name || "").trim() || !normalizedEmail || !password) {
    res.status(400);
    throw new Error("Name, email, and password are required");
  }

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

  res.status(201).json({
    token: generateToken(user._id, user.tokenVersion),
    user: serializeUser(user),
  });
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
      return res.status(428).json({ message: 'أدخل رمز التحقق المرسل إلى بريدك الإلكتروني.', requiresTwoFactor: true });
    }
    await consume(user, 'login', req.body.twoFactorCode, res);
  }

  user.lastLoginAt = new Date();
  await user.save();

  res.json({
    token: generateToken(user._id, user.tokenVersion),
    user: serializeUser(user),
  });
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
      emailVerified: false,
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
  }

  // Persist Google linkage before issuing a token or requesting a code.
  await user.save();

  // Email verification is required only once. Returning users who have already
  // verified skip the code step and log in directly via Google OAuth.
  if (!user.emailVerified) {
    if (!emailCode) {
      await sendCode(user, 'login', res);
      return res.status(428).json({
        message: 'أدخل رمز التأكيد المرسل إلى بريد حسابك في Google.',
        requiresEmailVerification: true,
      });
    }
    await consume(user, 'login', emailCode, res);
    user.emailVerified = true;
  }

  user.lastLoginAt = new Date();
  await user.save();

  if (user.role === "student") {
    await ensureStudentProfile(user._id);
  }

  res.json({
    token: generateToken(user._id, user.tokenVersion, { googlePasswordVerifiedAt: Date.now() }),
    user: serializeUser(user),
  });
});

const me = asyncHandler(async (req, res) => {
  // Middleware excludes the password; only expose whether one exists.
  const account = await User.findById(req.user._id).select("password");
  const profile =
    req.user.role === "student" || req.user.role === "partner"
      ? await StudentProfile.findOne({ user: req.user._id })
      : null;

  res.json({
    user: { ...req.user.toObject(), hasPassword: Boolean(account?.password) },
    profile,
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

  const passwordKinds = [/[A-Z]/, /[a-z]/, /[0-9]/, /[^A-Za-z0-9\s]/]
    .filter(pattern => pattern.test(newPassword)).length;
  if (passwordKinds < 2) {
    res.status(400);
    throw new Error('كلمة المرور ضعيفة. اخلط بين الأحرف الكبيرة والصغيرة أو الأرقام أو الرموز.');
  }

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
  await user.save();

  res.json({ message: "Password updated successfully" });
});

module.exports = {
  register,
  login,
  googleLogin,
  me,
  changePassword,
};
