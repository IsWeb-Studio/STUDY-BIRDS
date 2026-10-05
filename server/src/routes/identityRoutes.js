const express = require("express");
const crypto = require("node:crypto");
const { rateLimit } = require("express-rate-limit");
const { protect } = require("../middleware/authMiddleware");
const run = require("../utils/asyncHandler");
const User = require("../models/User");
const { Credential, Challenge } = require("../models/IdentityCredential");
const {
  serializeUser,
  ensureStudentProfile,
} = require("../controllers/authController");
const generateToken = require("../utils/generateToken");
const { sendCode, consume } = require("../utils/mobileEmailCodes");
const wa = require("../utils/whatsappOtp");
const router = express.Router();
const fail = (res, status, message) => {
  res.status(status);
  throw new Error(message);
};
router.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 60,
    standardHeaders: "draft-7",
    legacyHeaders: false,
    skip: (req) => req.method === "GET",
  }),
);
const rpID = () => process.env.WEBAUTHN_RP_ID;
const origins = () =>
  String(process.env.WEBAUTHN_ORIGINS || "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
const phoneReady = () => wa.ready();
router.get("/config", (req, res) =>
  res.json({
    passkeys: Boolean(rpID() && origins().length),
    apple: Boolean(
      process.env.APPLE_CLIENT_ID && process.env.APPLE_REDIRECT_URI,
    ),
    appleClientId: process.env.APPLE_CLIENT_ID || "",
    appleRedirectUri: process.env.APPLE_REDIRECT_URI || "",
    phone: phoneReady(),
  }),
);
async function saveChallenge(purpose, value, user) {
  const key = crypto.randomBytes(32).toString("base64url");
  await Challenge.create({
    key,
    purpose,
    value,
    user,
    expiresAt: new Date(Date.now() + 5 * 60 * 1000),
  });
  return key;
}
async function takeChallenge(req, res, purpose, user) {
  if (typeof req.body.challengeId !== "string")
    fail(res, 400, "Missing challenge");
  const row = await Challenge.findOneAndDelete({
    key: req.body.challengeId,
    purpose,
    ...(user ? { user } : {}),
    expiresAt: { $gt: new Date() },
  });
  if (!row) fail(res, 400, "Verification expired. Start again.");
  return row;
}
async function signIn(user, req, res) {
  if (!user || !user.isActive) fail(res, 401, "Unable to sign in");
  if (user.twoFactorEnabled) {
    if (!req.body.twoFactorCode) {
      await sendCode(user, "login", res);
      return res
        .status(428)
        .json({
          requiresTwoFactor: true,
          message: "Enter the code sent to your email and try again.",
        });
    }
    await consume(user, "login", req.body.twoFactorCode, res);
  }
  user.lastLoginAt = new Date();
  await user.save();
  res.json({
    token: generateToken(user._id, user.tokenVersion),
    user: serializeUser(user),
  });
}
function requirePasskeys(res) {
  if (!rpID() || !origins().length)
    fail(res, 503, "Passkeys are not configured");
}
async function requirePassword(req, res) {
  const user = await User.findById(req.user._id);
  if (
    typeof req.body.currentPassword !== "string" ||
    !user.password ||
    !(await user.comparePassword(req.body.currentPassword))
  )
    fail(res, 401, "Confirm your current password to register a passkey.");
}
router.post(
  "/passkeys/register/options",
  protect,
  run(async (req, res) => {
    requirePasskeys(res);
    await requirePassword(req, res);
    const { generateRegistrationOptions } =
      await import("@simplewebauthn/server");
    const existing = await Credential.find({ user: req.user._id }).lean();
    if (existing.length >= 10)
      fail(res, 400, "Maximum number of passkeys reached");
    const options = await generateRegistrationOptions({
      rpName: "Study Birds",
      rpID: rpID(),
      userName: req.user.email,
      userID: new TextEncoder().encode(String(req.user._id)),
      attestationType: "none",
      excludeCredentials: existing.map((c) => ({
        id: c.credentialID,
        transports: c.transports,
      })),
      authenticatorSelection: {
        residentKey: "required",
        userVerification: "required",
      },
    });
    const challengeId = await saveChallenge(
      "register",
      options.challenge,
      req.user._id,
    );
    res.json({ options, challengeId });
  }),
);
router.post(
  "/passkeys/register/verify",
  protect,
  run(async (req, res) => {
    requirePasskeys(res);
    const saved = await takeChallenge(req, res, "register", req.user._id);
    const { verifyRegistrationResponse } =
      await import("@simplewebauthn/server");
    let result;
    try {
      result = await verifyRegistrationResponse({
        response: req.body.response,
        expectedChallenge: saved.value,
        expectedOrigin: origins(),
        expectedRPID: rpID(),
        requireUserVerification: true,
      });
    } catch {
      fail(res, 400, "Passkey verification failed");
    }
    if (!result.verified) fail(res, 400, "Passkey verification failed");
    const c = result.registrationInfo.credential;
    await Credential.create({
      user: req.user._id,
      credentialID: c.id,
      publicKey: Buffer.from(c.publicKey),
      counter: c.counter,
      transports: c.transports,
      name: String(req.body.name || "Passkey").slice(0, 80),
    });
    res.status(201).json({ registered: true });
  }),
);
router.get(
  "/passkeys",
  protect,
  run(async (req, res) => {
    res.json(
      await Credential.find({ user: req.user._id })
        .select("_id name createdAt")
        .lean(),
    );
  }),
);
router.delete(
  "/passkeys/:id",
  protect,
  run(async (req, res) => {
    if (!require("mongoose").isValidObjectId(req.params.id))
      fail(res, 400, "Invalid passkey");
    const result = await Credential.deleteOne({
      _id: req.params.id,
      user: req.user._id,
    });
    if (!result.deletedCount) fail(res, 404, "Passkey not found");
    res.json({ removed: true });
  }),
);
router.post(
  "/passkeys/login/options",
  run(async (req, res) => {
    requirePasskeys(res);
    const { generateAuthenticationOptions } =
      await import("@simplewebauthn/server");
    const options = await generateAuthenticationOptions({
      rpID: rpID(),
      userVerification: "required",
    });
    res.json({
      options,
      challengeId: await saveChallenge("login", options.challenge),
    });
  }),
);
router.post(
  "/passkeys/login/verify",
  run(async (req, res) => {
    requirePasskeys(res);
    const saved = await takeChallenge(req, res, "login");
    if (typeof req.body.response?.id !== "string")
      fail(res, 400, "Invalid passkey");
    const c = await Credential.findOne({ credentialID: req.body.response.id });
    if (!c) fail(res, 401, "Unable to sign in");
    const { verifyAuthenticationResponse } =
      await import("@simplewebauthn/server");
    let result;
    try {
      result = await verifyAuthenticationResponse({
        response: req.body.response,
        expectedChallenge: saved.value,
        expectedOrigin: origins(),
        expectedRPID: rpID(),
        requireUserVerification: true,
        credential: {
          id: c.credentialID,
          publicKey: new Uint8Array(c.publicKey),
          counter: c.counter,
          transports: c.transports,
        },
      });
    } catch {
      fail(res, 401, "Unable to sign in");
    }
    if (!result.verified) fail(res, 401, "Unable to sign in");
    const updated = await Credential.updateOne(
      { _id: c._id, counter: c.counter },
      { $set: { counter: result.authenticationInfo.newCounter } },
    );
    if (!updated.matchedCount) fail(res, 401, "Please try again");
    await signIn(await User.findById(c.user), req, res);
  }),
);
router.post(
  "/apple/options",
  run(async (req, res) => {
    if (!process.env.APPLE_CLIENT_ID || !process.env.APPLE_REDIRECT_URI)
      fail(res, 503, "Apple sign-in is not configured");
    const nonce = crypto.randomBytes(32).toString("base64url");
    res.json({ nonce, state: await saveChallenge("apple", nonce) });
  }),
);
let appleKeys;
router.post(
  "/apple/verify",
  run(async (req, res) => {
    if (!process.env.APPLE_CLIENT_ID)
      fail(res, 503, "Apple sign-in is not configured");
    const saved = await takeChallenge(req, res, "apple");
    if (typeof req.body.identityToken !== "string")
      fail(res, 400, "Missing identity token");
    const { jwtVerify, createRemoteJWKSet } = await import("jose");
    appleKeys ||= createRemoteJWKSet(
      new URL("https://appleid.apple.com/auth/keys"),
    );
    let payload;
    try {
      ({ payload } = await jwtVerify(req.body.identityToken, appleKeys, {
        issuer: "https://appleid.apple.com",
        audience: process.env.APPLE_CLIENT_ID,
        algorithms: ["RS256"],
      }));
    } catch {
      fail(res, 401, "Invalid Apple identity");
    }
    if (payload.nonce !== saved.value || !payload.sub)
      fail(res, 401, "Invalid Apple challenge");
    let user = await User.findOne({ appleId: payload.sub });
    if (!user) {
      if (!payload.email || ![true, "true"].includes(payload.email_verified))
        fail(res, 400, "A verified Apple email is required");
      const email = String(payload.email).toLowerCase();
      if (await User.exists({ email }))
        fail(
          res,
          409,
          "This email already has an account. Use its existing sign-in method.",
        );
      user = await User.create({
        name: String(req.body.name || "Student").slice(0, 100),
        email,
        appleId: payload.sub,
        authProvider: "apple",
        emailVerified: true,
        role: "student",
      });
      await ensureStudentProfile(user._id);
    }
    await signIn(user, req, res);
  }),
);
router.post(
  "/phone/request",
  protect,
  rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 5,
    keyGenerator: (req) => String(req.user._id),
    standardHeaders: "draft-7",
    legacyHeaders: false,
  }),
  run(async (req, res) => {
    if (!phoneReady()) fail(res, 503, "Phone verification is not configured");
    if (
      typeof req.body.phone !== "string" ||
      !/^\+[1-9]\d{7,14}$/.test(req.body.phone)
    )
      fail(res, 400, "أدخل رقمًا دوليًا يبدأ بـ + ورمز الدولة");
    const key = `phone:${req.user._id}`;
    const existing = await Challenge.findOne({
      key,
      purpose: "phone",
      expiresAt: { $gt: new Date(Date.now() + 9 * 60 * 1000) },
    });
    if (existing) fail(res, 429, "انتظر دقيقة قبل طلب رمز جديد");
    await Challenge.deleteOne({ key });
    const code = wa.generate();
    try {
      await wa.send(req.body.phone, code);
    } catch (e) {
      fail(res, 503, e.message || "تعذر إرسال رمز التحقق");
    }
    await Challenge.create({
      key,
      user: req.user._id,
      purpose: "phone",
      phone: req.body.phone,
      value: wa.hash(req.body.phone, code),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    });
    res.json({ sent: true });
  }),
);
router.post(
  "/phone/confirm",
  protect,
  run(async (req, res) => {
    if (!phoneReady()) fail(res, 503, "Phone verification is not configured");
    if (typeof req.body.code !== "string" || !/^\d{6}$/.test(req.body.code))
      fail(res, 400, "أدخل الرمز المكون من 6 أرقام");
    const row = await Challenge.findOne({
      key: `phone:${req.user._id}`,
      purpose: "phone",
      expiresAt: { $gt: new Date() },
    });
    if (!row) fail(res, 400, "اطلب رمزًا جديدًا");
    if (row.value !== wa.hash(row.phone, req.body.code))
      fail(res, 400, "رمز التحقق غير صحيح");
    const consumed = await Challenge.deleteOne({ _id: row._id });
    if (!consumed.deletedCount) fail(res, 400, "تم استخدام الرمز بالفعل");
    await User.updateOne(
      { _id: req.user._id },
      { $set: { verifiedPhone: row.phone } },
    );
    res.json({ verifiedPhone: row.phone });
  }),
);
// Browser-to-app authorization: a one-time grant bound to a secret held by the app.
router.post(
  "/mobile/start",
  run(async (req, res) => {
    if (
      typeof req.body.challenge !== "string" ||
      !/^[A-Za-z0-9_-]{43}$/.test(req.body.challenge)
    )
      fail(res, 400, "Invalid proof challenge");
    const challengeId = await saveChallenge("mobile", req.body.challenge);
    const url = new URL("/mobile-sign-in", process.env.CLIENT_URL);
    if (
      url.protocol !== "https:" &&
      !["localhost", "127.0.0.1"].includes(url.hostname)
    )
      fail(res, 503, "Secure website URL required");
    url.searchParams.set("request", challengeId);
    res.json({ challengeId, url: url.toString() });
  }),
);
router.post(
  "/mobile/approve",
  protect,
  run(async (req, res) => {
    if (typeof req.body.challengeId !== "string")
      fail(res, 400, "Invalid request");
    const saved = await Challenge.findOneAndUpdate(
      {
        key: req.body.challengeId,
        purpose: "mobile",
        user: null,
        expiresAt: { $gt: new Date() },
      },
      { $set: { user: req.user._id } },
      { new: true },
    );
    if (!saved) fail(res, 400, "Request expired or already approved");
    res.json({ approved: true });
  }),
);
router.post(
  "/mobile/exchange",
  run(async (req, res) => {
    if (
      typeof req.body.verifier !== "string" ||
      !/^[A-Za-z0-9_-]{43}$/.test(req.body.verifier) ||
      typeof req.body.challengeId !== "string"
    )
      fail(res, 400, "Invalid proof");
    const value = crypto
      .createHash("sha256")
      .update(req.body.verifier)
      .digest("base64url");
    const saved = await Challenge.findOne({
      key: req.body.challengeId,
      purpose: "mobile",
      value,
      expiresAt: { $gt: new Date() },
    });
    if (!saved) fail(res, 400, "Request expired");
    if (!saved.user) return res.status(202).json({ pending: true });
    const used = await Challenge.findOneAndDelete({ _id: saved._id, value });
    if (!used) fail(res, 400, "Request already used");
    const user = await User.findById(saved.user);
    if (!user?.isActive) fail(res, 401, "Unable to sign in");
    res.json({
      token: generateToken(user._id, user.tokenVersion),
      user: serializeUser(user),
    });
  }),
);
module.exports = router;
