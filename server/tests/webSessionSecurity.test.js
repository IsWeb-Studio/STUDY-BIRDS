const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('web refresh credentials are HttpOnly, origin-bound, rotating and revocable; mobile remains compatible', async () => {
  process.env.JWT_SECRET = 'isolated-web-session-test-secret';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    await User.create({ name: 'Browser', email: 'browser@example.test', password: 'Sparrow!Secure2026', role: 'student' });
    const app = express(); app.use(express.json());
    app.use('/api/auth', require('../src/middleware/webSession')(new Set(['https://studybirds.net'])));
    app.use('/api/auth', require('../src/routes/authRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const call = async (route, body, headers = {}) => {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/${route}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body),
      });
      return { status: response.status, data: await response.json(), cookie: response.headers.get('set-cookie') };
    };
    const credentials = { email: 'browser@example.test', password: 'Sparrow!Secure2026' };
    const web = { Origin: 'https://studybirds.net', 'X-Study-Birds-Client': 'web' };
    const login = await call('login', credentials, web);
    assert.equal(login.status, 200); assert.equal(login.data.refreshToken, undefined);
    assert.match(login.cookie, /HttpOnly/); assert.match(login.cookie, /Secure/); assert.match(login.cookie, /SameSite=None/);
    const claims = jwt.verify(login.data.token, process.env.JWT_SECRET);
    assert.equal(claims.exp - claims.iat, 900);
    const cookie = login.cookie.split(';')[0];
    assert.equal((await call('refresh', {}, { ...web, Cookie: cookie, Origin: 'https://evil.example' })).status, 403);
    assert.equal((await call('refresh', {}, { Cookie: cookie })).status, 403);
    // A JSON credential cannot override a browser's cookie.
    const rotated = await call('refresh', { refreshToken: '0'.repeat(64) }, { ...web, Cookie: cookie });
    assert.equal(rotated.status, 200); assert.equal(rotated.data.refreshToken, undefined);
    assert.notEqual(rotated.cookie.split(';')[0], cookie);
    assert.equal((await call('refresh', {}, { ...web, Cookie: cookie })).status, 401);
    const nextCookie = rotated.cookie.split(';')[0];
    const logout = await call('logout', {}, { ...web, Cookie: nextCookie });
    assert.equal(logout.status, 200); assert.match(logout.cookie, /Expires=Thu, 01 Jan 1970/);
    assert.equal((await call('refresh', {}, { ...web, Cookie: nextCookie })).status, 401);
    const mobile = await call('login', credentials, { 'X-Study-Birds-Client': 'mobile' });
    assert.equal(mobile.status, 200); assert.match(mobile.data.refreshToken, /^[a-f0-9]{64}$/); assert.equal(mobile.cookie, null);
    assert.equal((await call('refresh', { refreshToken: mobile.data.refreshToken }, { 'X-Study-Birds-Client': 'mobile' })).status, 200);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
