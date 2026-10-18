const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const { OAuth2Client } = require('google-auth-library');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('first Google sign-in sets password before code verification; verified returning accounts skip onboarding', async () => {
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  const mailer = require('../src/utils/mailer');
  const original = { configured: mailer.isMailerConfigured, send: mailer.sendContactEmail, google: OAuth2Client.prototype.verifyIdToken };
  const codes = new Map();
  let sent = 0;
  process.env.JWT_SECRET = 'isolated-email-onboarding-secret';
  process.env.GOOGLE_CLIENT_ID = 'onboarding-test';
  mailer.isMailerConfigured = () => true;
  mailer.sendContactEmail = async mail => { sent++; codes.set(mail.to, mail.emailContent.code); };
  OAuth2Client.prototype.verifyIdToken = async () => ({ getPayload: () => ({ sub: 'onboarding-google', email: 'onboarding@example.test', email_verified: true, name: 'Onboarding' }) });
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const { EmailCode, Session } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), EmailCode.init(), Session.init()]);
    const app = express(); app.use(express.json());
    app.use('/auth', require('../src/routes/authRoutes'));
    app.use('/security', require('../src/routes/mobileSecurityRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(route, body, token) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}${route}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body),
      });
      return { status: response.status, data: await response.json() };
    }
    const first = await call('/auth/google', { credential: 'mock-google-proof' });
    assert.equal(first.status, 200);
    assert.equal(first.data.user.hasPassword, false);
    assert.equal(first.data.user.emailVerified, false);
    assert.equal(sent, 0);
    assert.equal((await call('/security/email/request', {}, first.data.token)).status, 409);
    assert.equal((await call('/security/email/confirm', { code: '123456' }, first.data.token)).status, 409);
    // Older Google registrations auto-set this flag before any password/code.
    await User.updateOne({ _id: first.data.user._id }, { $set: { emailVerified: true } });
    const saved = await call('/auth/change-password', { newPassword: 'Onboarding!Bird2026', passwordSetup: true }, first.data.token);
    assert.equal(saved.status, 200, JSON.stringify(saved));
    assert.equal(saved.data.user.hasPassword, true);
    assert.equal(saved.data.user.emailVerified, false);
    assert.equal((await call('/auth/google', { credential: 'mock-google-proof' })).data.user.emailVerified, false, 'retrying Google must not auto-verify');
    // A fresh Google login replaces the single refresh credential, but saved JWT remains valid.
    assert.equal((await call('/auth/email-otp/request', { email: first.data.user.email })).status, 403);
    assert.equal((await call('/security/email/request', {}, saved.data.token)).status, 200);
    const code = codes.get(first.data.user.email);
    assert.equal((await call('/security/email/confirm', { code: '000000' }, saved.data.token)).status, 400);
    assert.equal((await User.findById(first.data.user._id)).emailVerified, false);
    assert.equal((await call('/security/email/confirm', { code }, saved.data.token)).data.emailVerified, true);
    assert.equal((await User.findById(first.data.user._id)).emailVerified, true);
    assert.equal((await call('/security/email/confirm', { code }, saved.data.token)).status, 400);
    const before = sent;
    const returning = await call('/auth/google', { credential: 'mock-google-proof' });
    assert.equal(returning.status, 200);
    assert.equal(returning.data.user.emailVerified, true);
    assert.equal(returning.data.user.hasPassword, true);
    assert.equal(sent, before);
    assert.equal((await call('/security/email/request', {}, returning.data.token)).data.alreadyVerified, true);
    assert.equal((await call('/auth/email-otp/request', { email: first.data.user.email })).status, 200);
    assert.equal((await call('/auth/email-otp/verify', { email: first.data.user.email, code: codes.get(first.data.user.email) })).status, 200);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    mailer.isMailerConfigured = original.configured; mailer.sendContactEmail = original.send;
    OAuth2Client.prototype.verifyIdToken = original.google;
    await mongoose.disconnect(); await mongo.stop();
  }
});
