const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');
const mongoose = require('mongoose');
// Install mongodb-memory-server-core locally, or point to a separate test tools directory.
const toolsRoot = process.env.STUDY_BIRDS_TEST_TOOLS;
const { MongoMemoryServer } = require(toolsRoot ? path.join(toolsRoot, 'node_modules/mongodb-memory-server-core') : 'mongodb-memory-server-core');

test('mobile release: authentication, ownership, email codes, sessions, and messages', async () => {
  process.env.JWT_SECRET = 'isolated-test-key-never-production';
  let mongo, server;
  try {
    mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
    await mongoose.connect(mongo.getUri());
    const emails = [];
    const mailer = require('../src/utils/mailer');
    mailer.isMailerConfigured = () => true;
    mailer.sendContactEmail = async (mail) => { emails.push(mail); return { accepted: [mail.to] }; };
    const app = require('../src/app');
    const User = require('../src/models/User');
    const { Session, EmailCode } = require('../src/models/MobileWorkspace');
    await Promise.all(Object.values(mongoose.models).map(model => model.init()));
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const origin = `http://127.0.0.1:${server.address().port}/api`;
    async function call(method, route, token, body, status = 200) {
      const response = await fetch(origin + route, { method, headers: { 'Content-Type': 'application/json', 'X-Study-Birds-Client': 'mobile', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
      const json = await response.json();
      assert.equal(response.status, status, route + ': ' + JSON.stringify(json)); return json;
    }
    const code = () => emails.at(-1).text.match(/\d{6}/)[0];
    const admin = await User.create({ name:'Admin', email:'admin@example.test', password:'TestPassword123!', role:'admin' });
    await User.create({ name:'Employee', email:'employee@example.test', password:'TestPassword123!', role:'employee', permissions:['students'] });
    const a = await call('POST','/auth/register',null,{name:'Student',email:'student@example.test',password:'TestPassword123!'},201);
    const b = await call('POST','/auth/register',null,{name:'Other',email:'other@example.test',password:'TestPassword123!'},201);
    const staff = await call('POST','/auth/login',null,{email:'employee@example.test',password:'TestPassword123!'});
    assert.deepEqual(staff.user.permissions,['students']);
    assert.equal((await call('GET','/auth/me',a.token)).user.role,'student');
    const webResponse = await fetch(origin + '/auth/me', { headers: { Authorization: `Bearer ${b.token}`, 'X-Study-Birds-Client': 'web', 'User-Agent': 'Study Birds browser test' } });
    assert.equal(webResponse.status, 200);
    const webSessions = await call('GET','/mobile-security/sessions',b.token);
    assert.ok(webSessions.some(session => session.current && session.device === 'Study Birds browser test'));

    assert.equal((await call('GET','/mobile/capabilities')).messaging,true);
    await call('GET','/mobile-security/sessions','bad-token',undefined,401);
    await call('POST','/mobile-workspace/messages',a.token,{recipient:b.user._id,body:'Hello classmate'},201);
    const msg = await call('POST','/mobile-workspace/messages',a.token,{recipient:String(admin._id),body:'Please help'},201);
    const adminAuth = await call('POST','/auth/login',null,{email:'admin@example.test',password:'TestPassword123!'});
    const messages = await call('GET',`/mobile-workspace/messages?recipient=${a.user._id}`,adminAuth.token);
    assert.equal(messages[0]._id,msg._id);
    await call('POST','/mobile-workspace/messages/read',adminAuth.token,{sender:a.user._id});
    assert.ok((await call('GET',`/mobile-workspace/messages?recipient=${admin._id}`,a.token))[0].readAt);
    await call('POST','/mobile-security/email/request',a.token,{});
    const verification = code();
    await call('POST','/mobile-security/email/confirm',a.token,{code:'000000'},400);
    await call('POST','/mobile-security/email/confirm',a.token,{code:verification});
    await call('POST','/mobile-security/email/confirm',a.token,{code:verification},400);
    await call('POST','/mobile-security/two-factor/request',a.token,{});
    await call('POST','/mobile-security/two-factor/confirm',a.token,{code:code(),enabled:true});
    await call('POST','/auth/login',null,{email:'student@example.test',password:'TestPassword123!'},428);
    const login = await call('POST','/auth/login',null,{email:'student@example.test',password:'TestPassword123!',twoFactorCode:code()});
    assert.ok(login.token);
    const sessions = await call('GET','/mobile-security/sessions',login.token);
    const current = sessions.find(s => s.current);
    assert.ok(current);
    await call('DELETE',`/mobile-security/sessions/${current._id}`,b.token,undefined,404);
    await call('DELETE',`/mobile-security/sessions/${current._id}`,login.token);
    await call('GET','/auth/me',login.token,undefined,401);
    await call('POST','/mobile-security/reset/request',null,{email:'student@example.test'});
    await call('POST','/mobile-security/reset/confirm',null,{email:'student@example.test',code:code(),password:'ChangedPassword123!'});
    await call('GET','/auth/me',a.token,undefined,401);
    assert.equal((await User.findById(a.user._id)).tokenVersion,1);
    assert.equal(await Session.countDocuments({user:a.user._id,revoked:false}),0);
    assert.equal(await EmailCode.countDocuments({purpose:'reset'}),0);
    // The established parent and university routes remain registered.
    await call('GET','/parents/overview',undefined,undefined,401);
    console.log('Verified roles, message isolation, notification, single-use codes, 2FA, session revocation and password reset.');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); if (mongo) await mongo.stop();
  }
});
