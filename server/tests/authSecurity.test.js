const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('authentication security regressions with real MongoDB and HTTP', async t => {
  process.env.JWT_SECRET = 'isolated-auth-security-test-secret';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  const mailer = require('../src/utils/mailer');
  const sms = require('../src/utils/cashMisrSms');
  const original = { configured: mailer.isMailerConfigured, mail: mailer.sendContactEmail, ready: sms.ready, send: sms.send };
  const codes = new Map();
  let smsSends = 0;
  mailer.isMailerConfigured = () => true;
  mailer.sendContactEmail = async mail => { codes.set(mail.to, mail.emailContent.code); };
  sms.ready = () => true;
  sms.send = async () => { smsSends++; };
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const { EmailCode, Session } = require('../src/models/MobileWorkspace');
    const { Challenge } = require('../src/models/IdentityCredential');
    const { issueTokenPair } = require('../src/controllers/authController');
    await Promise.all([User.init(), EmailCode.init(), Session.init(), Challenge.init()]);
    const app = express();
    app.use(express.json());
    app.use('/api/auth', require('../src/routes/authRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(route, body, token) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/${route}`, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      return { status: response.status, data: await response.json() };
    }
    const password = 'Sparrow!Secure2026';
    async function account(name, extra = {}) {
      return User.create({ name, email: `${name}@example.test`, password, role: 'admin', ...extra });
    }
    async function login(user, pass = password) {
      const response = await call('login', { email: user.email, password: pass });
      assert.equal(response.status, 200, JSON.stringify(response));
      return response.data;
    }
    await t.test('email OTP cannot replace two factors, even with an already-issued valid code', async () => {
      const user = await account('twofactor');
      assert.equal((await call('email-otp/request', { email: user.email })).status, 200);
      const code = codes.get(user.email);
      await User.updateOne({ _id: user._id }, { $set: { twoFactorEnabled: true } });
      assert.equal((await call('email-otp/request', { email: user.email })).status, 403);
      const bypass = await call('email-otp/verify', { email: user.email, code });
      assert.equal(bypass.status, 403); assert.equal(bypass.data.token, undefined);
      const challenge = await call('login', { email: user.email, password });
      assert.equal(challenge.status, 428); assert.equal(challenge.data.token, undefined);
      const verified = await call('login', { email: user.email, password, twoFactorCode: codes.get(user.email) });
      assert.equal(verified.status, 200); assert.ok(verified.data.token);
    });
    await t.test('phone OTP cannot bypass two factors', async () => {
      const phone = '+201012345678';
      await account('phone2fa', { verifiedPhone: phone, twoFactorEnabled: true });
      assert.equal((await call('otp/request', { phone })).status, 403); assert.equal(smsSends, 0);
      await Challenge.create({ key: `otp-login:${phone}`, purpose: 'otp-login', value: sms.hash(phone, '123456'), expiresAt: new Date(Date.now() + 60000) });
      const bypass = await call('otp/verify', { phone, code: '123456' });
      assert.equal(bypass.status, 403); assert.equal(bypass.data.token, undefined);
    });
    await t.test('ordinary email OTP remains available and its code is single-use', async () => {
      const user = await account('emailonly');
      await call('email-otp/request', { email: user.email });
      const body = { email: user.email, code: codes.get(user.email) };
      const response = await call('email-otp/verify', body);
      assert.equal(response.status, 200); assert.ok(response.data.refreshToken);
      assert.equal((await call('email-otp/verify', body)).status, 400);
    });
    await t.test('password changes revoke every old JWT and refresh token and return a usable replacement', async () => {
      const user = await account('passwordchange');
      const first = await login(user), second = await login(user);
      const nextPassword = 'Swallow!Replacement2026';
      const changed = await call('change-password', { currentPassword: password, newPassword: nextPassword }, second.token);
      assert.equal(changed.status, 200, JSON.stringify(changed));
      assert.equal(jwt.decode(changed.data.token).tokenVersion, 1);
      assert.equal((await call('me', undefined, first.token)).status, 401);
      assert.equal((await call('me', undefined, second.token)).status, 401);
      assert.equal((await call('refresh', { refreshToken: second.refreshToken })).status, 401);
      assert.equal((await call('me', undefined, changed.data.token)).status, 200);
      assert.equal((await call('refresh', { refreshToken: changed.data.refreshToken })).status, 200);
      assert.equal((await call('login', { email: user.email, password })).status, 401);
      await login(user, nextPassword);
    });
    await t.test('logout with bearer revokes all account JWTs and ignores a different user refresh token', async () => {
      const user = await account('logoutbearer'), other = await account('otherowner');
      const first = await login(user), second = await login(user), untouched = await login(other);
      assert.equal((await call('logout', { refreshToken: untouched.refreshToken }, first.token)).status, 200);
      assert.equal((await call('me', undefined, second.token)).status, 401);
      assert.equal((await call('refresh', { refreshToken: second.refreshToken })).status, 401);
      assert.equal((await call('me', undefined, untouched.token)).status, 200);
      assert.equal((await call('refresh', { refreshToken: untouched.refreshToken })).status, 200);
    });
    await t.test('refresh-only mobile logout revokes JWTs and rejects missing or fake credentials', async () => {
      const user = await account('logoutmobile');
      const tokens = await login(user);
      assert.equal((await call('logout', { refreshToken: tokens.refreshToken })).status, 200);
      assert.equal((await call('me', undefined, tokens.token)).status, 401);
      assert.equal((await call('refresh', { refreshToken: tokens.refreshToken })).status, 401);
      assert.equal((await call('logout', {})).status, 401);
      assert.equal((await call('logout', { refreshToken: 'a'.repeat(64) })).status, 401);
      assert.equal((await call('logout', {}, 'invalid-jwt')).status, 401);
    });
    await t.test('concurrent refresh requests have exactly one winner; replay fails', async () => {
      const user = await account('rotation');
      const tokens = await login(user);
      const responses = await Promise.all(Array.from({ length: 12 }, () => call('refresh', { refreshToken: tokens.refreshToken })));
      assert.equal(responses.filter(r => r.status === 200).length, 1);
      assert.equal(responses.filter(r => r.status === 401).length, 11);
      const winner = responses.find(r => r.status === 200).data;
      assert.equal((await call('refresh', { refreshToken: tokens.refreshToken })).status, 401);
      assert.equal((await call('me', undefined, winner.token)).status, 200);
      assert.equal((await call('refresh', { refreshToken: winner.refreshToken })).status, 200);
      assert.equal((await call('refresh', { refreshToken: { $ne: null } })).status, 400);
    });
    await t.test('disabled or expired accounts cannot refresh; stale issuance cannot undo logout', async () => {
      const user = await account('expired');
      let tokens = await login(user);
      await User.updateOne({ _id: user._id }, { $set: { refreshTokenExpiry: new Date(0) } });
      assert.equal((await call('refresh', { refreshToken: tokens.refreshToken })).status, 401);
      tokens = await login(user);
      await User.updateOne({ _id: user._id }, { $set: { isActive: false } });
      assert.equal((await call('refresh', { refreshToken: tokens.refreshToken })).status, 401);
      await User.updateOne({ _id: user._id }, { $set: { isActive: true } });
      const stale = await User.findById(user._id);
      assert.equal((await call('logout', { refreshToken: tokens.refreshToken })).status, 200);
      await assert.rejects(issueTokenPair(stale), error => error.statusCode === 401);
      assert.equal((await User.findById(user._id).select('+refreshTokenHash')).refreshTokenHash, undefined);
    });
  } finally {
    mailer.isMailerConfigured = original.configured; mailer.sendContactEmail = original.mail;
    sms.ready = original.ready; sms.send = original.send;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
