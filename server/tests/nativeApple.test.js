const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const express = require('express');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('native Apple verifies signed identity, bundle, nonce, replay, account boundaries and optional 2FA', async () => {
  process.env.JWT_SECRET = 'native-apple-local-test';
  delete process.env.APPLE_CLIENT_ID;
  delete process.env.APPLE_REDIRECT_URI;
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  const originalFetch = global.fetch;
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const jose = await import('jose');
    const key = await jose.generateKeyPair('RS256');
    const jwk = await jose.exportJWK(key.publicKey); jwk.kid = 'native-test';
    global.fetch = (input, init) => String(input) === 'https://appleid.apple.com/auth/keys'
      ? Promise.resolve(new Response(JSON.stringify({ keys: [jwk] }), { headers: { 'Content-Type': 'application/json' } }))
      : originalFetch(input, init);
    let emailCode;
    const mailer = require('../src/utils/mailer');
    mailer.isMailerConfigured = () => true;
    mailer.sendContactEmail = async mail => { emailCode = mail.emailContent.code; };
    const User = require('../src/models/User');
    const { Challenge } = require('../src/models/IdentityCredential');
    const { EmailCode } = require('../src/models/MobileWorkspace');
    await Promise.all([User.init(), Challenge.init(), EmailCode.init()]);
    const app = express(); app.use(express.json()); app.use('/apple', require('../src/routes/nativeAppleRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(route, body = {}) {
      const response = await originalFetch(`http://127.0.0.1:${server.address().port}/apple/${route}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
      });
      return { status: response.status, data: await response.json() };
    }
    async function proof({ aud = 'com.studybirds.studyBirds', nonce, sub = 'apple-student', email = 'apple@example.test' } = {}) {
      const options = (await call('options')).data;
      const identityToken = await new jose.SignJWT({ nonce: nonce ?? options.nonce, ...(email ? { email, email_verified: true } : {}) })
        .setProtectedHeader({ alg: 'RS256', kid: jwk.kid }).setIssuer('https://appleid.apple.com')
        .setAudience(aud).setSubject(sub).setIssuedAt().setExpirationTime('5m').sign(key.privateKey);
      return { challengeId: options.challengeId, identityToken, name: 'Apple Student' };
    }
    assert.equal((await call('verify', await proof({ aud: 'wrong.bundle' }))).status, 401);
    assert.equal((await call('verify', await proof({ nonce: 'wrong-nonce' }))).status, 401);
    const good = await proof();
    const login = await call('verify', good);
    assert.equal(login.status, 200, JSON.stringify(login));
    assert.ok(login.data.token); assert.ok(login.data.refreshToken);
    assert.equal(login.data.user.authProvider, 'apple'); assert.equal(login.data.user.hasPassword, false);
    assert.equal((await call('verify', good)).status, 401);
    const returning = await call('verify', await proof({ email: null }));
    assert.equal(returning.status, 200); assert.equal(returning.data.user._id, login.data.user._id);
    await User.create({ name: 'Local account', email: 'existing@example.test', role: 'student' });
    assert.equal((await call('verify', await proof({ sub: 'another', email: 'existing@example.test' }))).status, 409);
    await User.updateOne({ _id: login.data.user._id }, { $set: { isActive: false } });
    assert.equal((await call('verify', await proof())).status, 403);
    await User.updateOne({ _id: login.data.user._id }, { $set: { isActive: true, twoFactorEnabled: true } });
    const pending = await call('verify', await proof());
    assert.equal(pending.status, 428); assert.equal(pending.data.token, undefined); assert.ok(emailCode);
    assert.equal((await call('confirm', { challengeId: pending.data.challengeId, emailCode: 'wrong' })).status, 400);
    const confirmed = await call('confirm', { challengeId: pending.data.challengeId, emailCode });
    assert.equal(confirmed.status, 200); assert.ok(confirmed.data.refreshToken);
    assert.equal((await call('confirm', { challengeId: pending.data.challengeId, emailCode })).status, 401);
  } finally {
    global.fetch = originalFetch;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
