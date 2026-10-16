const router = require('express').Router();
const crypto = require('node:crypto');
const run = require('../utils/asyncHandler');
const User = require('../models/User');
const { Challenge } = require('../models/IdentityCredential');
const { serializeUser, ensureStudentProfile, issueTokenPair } = require('../controllers/authController');
const { sendCode, consume } = require('../utils/mobileEmailCodes');
const fail = (statusCode, message) => { throw Object.assign(new Error(message), { statusCode }); };
const audience = () => process.env.APPLE_IOS_BUNDLE_ID || 'com.studybirds.studyBirds';
let keys;
async function challenge(purpose, value, user) {
  const key = crypto.randomBytes(32).toString('base64url');
  await Challenge.create({ key, purpose, value, user, expiresAt: new Date(Date.now() + 5 * 60000) });
  return key;
}
async function session(user, res) {
  if (!user?.isActive) fail(403, 'Account unavailable');
  user.lastLoginAt = new Date();
  await user.save();
  if (user.role === 'student') await ensureStudentProfile(user._id);
  res.json({ ...await issueTokenPair(user), user: serializeUser(user) });
}
router.post('/options', run(async (req, res) => {
  const nonce = crypto.randomBytes(32).toString('base64url');
  res.json({ nonce, challengeId: await challenge('apple-native', nonce) });
}));
router.post('/verify', run(async (req, res) => {
  if (typeof req.body.challengeId !== 'string' || typeof req.body.identityToken !== 'string') fail(400, 'Missing Apple credential');
  const proof = await Challenge.findOneAndDelete({ key: req.body.challengeId, purpose: 'apple-native', expiresAt: { $gt: new Date() } });
  if (!proof) fail(401, 'Apple verification expired');
  const { createRemoteJWKSet, jwtVerify } = await import('jose');
  keys ||= createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
  let payload;
  try {
    ({ payload } = await jwtVerify(req.body.identityToken, keys, {
      issuer: 'https://appleid.apple.com', audience: audience(), algorithms: ['RS256'],
    }));
  } catch { fail(401, 'Invalid Apple identity'); }
  if (!payload.sub || payload.nonce !== proof.value) fail(401, 'Invalid Apple nonce');
  let user = await User.findOne({ appleId: payload.sub });
  if (!user) {
    if (typeof payload.email !== 'string' || ![true, 'true'].includes(payload.email_verified)) fail(400, 'Verified Apple email required');
    const email = payload.email.trim().toLowerCase();
    // Never silently link an existing account just because an email matches.
    if (await User.exists({ email })) fail(409, 'Use the existing sign-in method for this email');
    user = await User.create({ appleId: payload.sub, email, emailVerified: true, authProvider: 'apple',
      name: typeof req.body.name === 'string' && req.body.name.trim() ? req.body.name.trim().slice(0, 100) : 'Student', role: 'student' });
  }
  if (!user.isActive) fail(403, 'Account unavailable');
  if (user.twoFactorEnabled) {
    await sendCode(user, 'login', res);
    return res.status(428).json({ requiresTwoFactor: true,
      challengeId: await challenge('apple-native-login', String(user._id), user._id) });
  }
  await session(user, res);
}));
async function pending(req) {
  if (typeof req.body.challengeId !== 'string') fail(400, 'Missing Apple challenge');
  const proof = await Challenge.findOne({ key: req.body.challengeId, purpose: 'apple-native-login', expiresAt: { $gt: new Date() } });
  if (!proof) fail(401, 'Apple verification expired');
  const user = await User.findById(proof.user);
  if (!user?.isActive) fail(403, 'Account unavailable');
  return { proof, user };
}
router.post('/confirm', run(async (req, res) => {
  const { proof, user } = await pending(req);
  await consume(user, 'login', req.body.emailCode, res);
  const used = await Challenge.findOneAndDelete({ _id: proof._id });
  if (!used) fail(401, 'Apple verification expired');
  await session(user, res);
}));
router.post('/resend', run(async (req, res) => {
  const { user } = await pending(req);
  await sendCode(user, 'login', res);
  res.json({ sent: true });
}));
module.exports = router;
