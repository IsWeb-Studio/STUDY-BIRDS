// Full Express + real MongoDB integration. Uses a temporary localhost database.
// Only Cloudinary's external storage adapter is replaced; multipart parsing,
// authentication, validation, queries, persistence, and ownership checks are real.
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const path = require('node:path');
const fs = require('node:fs');
const site = process.env.STUDY_BIRDS_SITE || 'D:/work/Study-birds';
const testTools = process.env.STUDY_BIRDS_TEST_TOOLS || 'D:/Temp/study-birds-test-tools';
const requireSite = createRequire(path.join(site, 'server/package.json'));
const { MongoMemoryServer } = require(path.join(testTools, 'node_modules/mongodb-memory-server-core'));
const mongoose = requireSite('mongoose');
process.env.JWT_SECRET = 'local-integration-test-only';
process.env.NODE_ENV = 'test';
let mongo, server, origin, passed = 0;
const sentMail = [];
const pass = (label) => { passed++; console.log(`PASS ${passed}: ${label}`); };
async function request(method, route, token, body, expected = 200) {
  const multipart = body instanceof FormData;
  const response = await fetch(origin + route, {
    method, headers: { 'X-Study-Birds-Client': 'mobile', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(!multipart && body ? { 'Content-Type': 'application/json' } : {}) },
    body: multipart ? body : body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json();
  assert.equal(response.status, expected, `${method} ${route}: ${JSON.stringify(data)}`);
  return data;
}
const form = (fields = {}) => {
  const data = new FormData();
  data.append('file', new Blob(['%PDF-1.4\nIntegration fixture'], { type: 'application/pdf' }), 'test-document.pdf');
  for (const [key, value] of Object.entries(fields)) data.append(key, value);
  return data;
};

(async () => {
  try {
    mongo = await MongoMemoryServer.create({ binary: { downloadDir: 'D:/Temp/study-birds-mongodb' }, instance: { dbName: 'study_birds_mobile_test', ip: '127.0.0.1' } });
    process.env.MONGODB_URI = mongo.getUri();
    await mongoose.connect(process.env.MONGODB_URI);
    const uploader = requireSite('./src/utils/uploadToCloudinary');
    uploader.uploadFileToCloudinary = async (file) => ({ url: `https://storage.example.test/${encodeURIComponent(file.originalname)}`, bytes: file.size });
    const mailer = requireSite('./src/utils/mailer');
    mailer.isMailerConfigured = () => true;
    mailer.sendContactEmail = async (message) => { sentMail.push(message); return { accepted: [message.to] }; };
    const app = requireSite('./src/app');
    await Promise.all(Object.values(mongoose.models).map((model) => model.init()));
    server = await new Promise((resolve) => { const listener = app.listen(0, '127.0.0.1', () => resolve(listener)); });
    origin = `http://127.0.0.1:${server.address().port}/api`;
    const User = requireSite('./src/models/User');
    await User.create({ name: 'Integration admin', email: 'admin@example.test', password: 'TestPassword123!', role: 'admin' });
    await User.create({ name: 'Integration partner', email: 'partner@example.test', password: 'TestPassword123!', role: 'partner' });
    const admin = await request('POST', '/auth/login', null, { email: 'admin@example.test', password: 'TestPassword123!' });
    const student = await request('POST', '/auth/register', null, { name: 'Test student', email: 'student@example.test', password: 'TestPassword123!' }, 201);
    const other = await request('POST', '/auth/register', null, { name: 'Other student', email: 'other@example.test', password: 'TestPassword123!' }, 201);
    const partner = await request('POST', '/auth/login', null, { email: 'partner@example.test', password: 'TestPassword123!' });
    assert.equal((await request('GET', '/auth/me', student.token)).user.email, 'student@example.test');
    pass('website login and registration create persistent mobile sessions');

    const config = await request('GET', '/mobile/config');
    config.title = 'اختبار التطبيق';
    config.modules.find((m) => m.key === 'travel').enabled = false;
    const saved = await request('PUT', '/mobile/admin/settings', admin.token, config);
    assert.equal(saved.revision, 1);
    assert.equal((await request('GET', '/mobile/config')).title, config.title);
    await request('PUT', '/mobile/admin/settings', admin.token, config, 409);
    await request('PUT', '/mobile/admin/settings', student.token, saved, 403);
    pass('admin settings persist and stale/student writes are rejected');

    const service = await request('POST', '/mobile/admin/content', admin.token, { section: 'services', title: 'استشارة دراسية', body: 'تفاصيل الخدمة', published: true, requestable: true, order: 0 }, 201);
    assert.equal((await request('GET', '/mobile/content?section=services'))[0].title, service.title);
    const booking = await request('POST', '/mobile/requests', student.token, { contentId: service._id, message: 'أرغب في استشارة', user: other.user._id }, 201);
    assert.equal(booking.user, student.user._id);
    await request('PATCH', `/mobile/admin/requests/${booking._id}`, admin.token, { status: 'in-progress', adminNote: 'تم تحديد موعد' });
    assert.equal((await request('GET', '/mobile/requests', student.token))[0].adminNote, 'تم تحديد موعد');
    assert.deepEqual(await request('GET', '/mobile/requests', other.token), []);
    await request('PUT', `/mobile/admin/content/${service._id}`, admin.token, { ...service, published: false });
    assert.deepEqual(await request('GET', '/mobile/content?section=services'), []);
    await request('POST', '/mobile/requests', student.token, { contentId: service._id, message: 'Should fail' }, 404);
    pass('content publishing, owned service requests, and admin replies persist');

    const documents = [];
    for (const type of ['passport', 'biometric-photo', 'latest-qualification']) documents.push(await request('POST', '/students/documents', student.token, form({ type }), 201));
    assert.equal((await request('GET', '/students/documents', student.token)).length, 3);
    assert.equal((await request('GET', '/students/documents', other.token)).length, 0);
    await request('PATCH', `/mobile/admin/documents/${documents[0]._id}`, admin.token, { status: 'verified' });
    assert.equal((await request('GET', '/students/documents', student.token)).find((d) => d._id === documents[0]._id).status, 'verified');
    pass('multipart document upload, storage metadata, ownership, and admin review');

    const country = await request('POST', '/admin/countries', admin.token, { name: 'Test country', code: 'TC' }, 201);
    const university = await request('POST', '/universities', admin.token, { name: 'Test university', country: country._id }, 201);
    const program = await request('POST', '/programs', admin.token, { title: 'Computer science', university: university._id, degreeLevel: 'bachelor', fieldOfStudy: 'Technology', tuition: 1000 }, 201);
    assert.equal((await request('GET', `/programs/${program._id}`)).title, program.title);
    const application = await request('POST', '/applications', student.token, { programId: program._id, documentIds: documents.map((d) => d._id) }, 201);
    await request('GET', `/applications/${application._id}`, other.token, undefined, 403);
    await request('GET', '/applications', partner.token, undefined, 403);
    await request('GET', `/applications/${application._id}`, partner.token, undefined, 403);
    await request('PUT', `/applications/${application._id}/status`, admin.token, { status: 'accepted', note: 'Accepted in integration test' });
    assert.equal((await request('GET', '/students/applications', student.token))[0].status, 'accepted');
    await request('POST', '/students/favorites/toggle', student.token, { itemType: 'program', programId: program._id }, 201);
    assert.equal((await request('GET', '/students/favorites', student.token)).length, 1);
    pass('shared catalogs, application submission, review, and favorites');

    await request('PUT', '/students/profile', student.token, { phone: '12345', applicationStage: 'final-accepted' });
    assert.equal((await request('GET', '/students/profile', student.token)).applicationStage, 'file-received');
    await request('PUT', '/students/arrival-services', student.token, { airport: 'Test airport' }, 400);
    await request('PATCH', `/mobile/admin/students/${student.user._id}/stage`, admin.token, { applicationStage: 'final-accepted' });
    const arrival = await request('PUT', '/students/arrival-services', student.token, { airport: 'Test airport', services: { airportPickup: true } });
    assert.equal(arrival.services.airportPickup, true);
    pass('only administrative acceptance unlocks arrival services');

    const invoice = await request('POST', '/admin/student-financials/invoices', admin.token, { studentId: student.user._id, invoiceNumber: 'TEST-001', description: 'Application fee', amount: 100 }, 201);
    await request('POST', `/students/financials/invoices/${invoice._id}/payment-proof`, other.token, form(), 404);
    const proof = await request('POST', `/students/financials/invoices/${invoice._id}/payment-proof`, student.token, form(), 201);
    await request('PATCH', `/admin/student-financials/payment-proofs/${proof._id}`, admin.token, { status: 'approved' });
    assert.equal((await request('GET', '/students/financials', student.token)).invoices[0].status, 'paid');
    pass('invoice creation, owned payment proof upload, and payment review');

    const ticket = await request('POST', '/students/support-tickets', student.token, { subject: 'Question', message: 'Hello', category: 'other' }, 201);
    await request('PATCH', `/admin/support-tickets/${ticket._id}/reply`, admin.token, { message: 'Admin answer', status: 'answered' });
    await request('POST', `/mobile/tickets/${ticket._id}/reply`, other.token, { message: 'Wrong owner' }, 404);
    await request('POST', `/mobile/tickets/${ticket._id}/reply`, student.token, { message: 'Thank you' });
    const tickets = await request('GET', '/students/support-tickets', student.token);
    assert.equal(tickets[0].replies.length, 3);
    await request('POST', '/mobile/admin/notifications', admin.token, { userId: student.user._id, title: 'إشعار تجريبي', message: 'تم التحديث' }, 201);
    const notification = (await request('GET', '/students/notifications', student.token)).find((n) => n.title === 'إشعار تجريبي');
    await request('PATCH', `/students/notifications/${notification._id}/read`, student.token);
    assert.equal((await request('GET', '/students/notifications', student.token)).find((n) => n._id === notification._id).isRead, true);
    pass('two-way support threads and persistent read notifications');

    const agentStudent = await request('POST', '/partners/students', partner.token, { name: 'Agent student', email: 'agentstudent@example.test', phone: '12345', applicationStatus: 'final-accepted' }, 201);
    assert.equal(agentStudent.applicationStatus, 'under-review');
    assert.equal((await request('GET', '/partners/students', partner.token))[0]._id, agentStudent._id);
    await request('GET', '/partners/students', student.token, undefined, 403);
    await request('POST', '/partners/wallet/payout-requests', partner.token, { amount: 25, method: 'bank-account', payoutDetails: 'Test transfer details' }, 201);
    pass('partner mobile operations use existing role-protected APIs');
    await request('POST', '/auth/register', null, { name: 'Forbidden', email: 'forbidden@example.test', password: 'TestPassword123!', role: 'employee' }, 403);
    const parent = await request('POST', '/auth/register', null, { name: 'Parent', email: 'parent@example.test', password: 'TestPassword123!', role: 'parent' }, 201);
    const employeeUser = await request('POST', '/mobile-workspace/admin/accounts', admin.token, { name: 'Employee', email: 'employee@example.test', password: 'TestPassword123!', role: 'employee' }, 201);
    const uniUser = await request('POST', '/mobile-workspace/admin/accounts', admin.token, { name: 'University', email: 'university@example.test', password: 'TestPassword123!', role: 'university' }, 201);
    const employee = await request('POST', '/auth/login', null, { email: employeeUser.email, password: 'TestPassword123!' });
    const uniSession = await request('POST', '/auth/login', null, { email: uniUser.email, password: 'TestPassword123!' });
    await request('POST', '/mobile-workspace/admin/accounts', student.token, { ...employeeUser, email: 'escalate@example.test', password: 'TestPassword123!' }, 403);
    assert.deepEqual(await request('GET', '/mobile-workspace/students', parent.token), []);
    await request('GET', `/mobile-workspace/students/${student.user._id}`, parent.token, undefined, 404);
    await request('PUT', `/mobile-workspace/admin/accounts/${parent.user._id}/access`, admin.token, { students: [student.user._id], manager: true });
    await request('PUT', `/mobile-workspace/admin/accounts/${employeeUser._id}/access`, admin.token, { students: [student.user._id], manager: true });
    await request('PUT', `/mobile-workspace/admin/accounts/${uniUser._id}/access`, admin.token, { students: [], university: university._id });
    assert.equal((await request('GET', '/mobile-workspace/students', parent.token)).length, 1);
    assert.equal((await request('GET', `/mobile-workspace/students/${student.user._id}`, parent.token)).documents.length, 3);
    await request('GET', `/mobile-workspace/students/${other.user._id}`, parent.token, undefined, 404);
    await request('GET', `/mobile-workspace/students/${other.user._id}`, employee.token, undefined, 404);
    await request('GET', '/mobile-workspace/manager', parent.token, undefined, 403);
    assert.equal((await request('GET', '/mobile-workspace/overview', parent.token)).manager, false);
    pass('parent and employee relationships enforce assigned-student scope and prevent self-promotion');

    const foreignUni = await request('POST', '/universities', admin.token, { name: 'Other university', country: country._id }, 201);
    const foreignProgram = await request('POST', '/programs', admin.token, { title: 'Other program', university: foreignUni._id, degreeLevel: 'bachelor', fieldOfStudy: 'Technology', tuition: 1000 }, 201);
    const foreignApplication = await request('POST', '/applications', student.token, { programId: foreignProgram._id, documentIds: documents.map(d => d._id) }, 201);
    assert.equal((await request('GET', '/mobile-workspace/applications', uniSession.token)).length, 1);
    await request('PATCH', `/mobile-workspace/applications/${foreignApplication._id}/status`, uniSession.token, { status: 'accepted', note: 'Forbidden' }, 404);
    await request('PATCH', `/mobile-workspace/applications/${application._id}/status`, parent.token, { status: 'accepted', note: 'Forbidden' }, 403);
    await request('PATCH', `/mobile-workspace/applications/${application._id}/status`, uniSession.token, { status: 'accepted', note: 'University decision' });
    await request('POST', `/mobile-workspace/applications/${application._id}/document-request`, uniSession.token, { message: 'Please update passport' }, 201);
    await request('POST', `/mobile-workspace/applications/${application._id}/admission-letter`, uniSession.token, form(), 201);
    assert.equal((await request('GET', `/mobile-workspace/applications/${application._id}`, student.token)).decisions.length, 2);
    pass('university review, requested documents and admission letters are isolated by university');

    const task = await request('POST', '/mobile-workspace/admin/tasks', admin.token, { title: 'Review student', assignedTo: employeeUser._id, student: student.user._id }, 201);
    await request('POST', '/mobile-workspace/admin/tasks', admin.token, { title: 'Unassigned student', assignedTo: employeeUser._id, student: other.user._id }, 400);
    await request('PATCH', `/mobile-workspace/tasks/${task._id}`, employee.token, { status: 'completed' });
    assert.equal((await request('GET', '/mobile-workspace/tasks', employee.token))[0].status, 'completed');
    assert.equal((await request('GET', '/mobile-workspace/manager', employee.token)).students, 1);
    const message = await request('POST', '/mobile-workspace/messages', parent.token, { recipient: employeeUser._id, body: 'Hello advisor' }, 201);
    await request('POST', '/mobile-workspace/messages', parent.token, { recipient: other.user._id, body: 'Forbidden' }, 403);
    assert.equal((await request('GET', '/mobile-workspace/messages', employee.token))[0].body, 'Hello advisor');
    assert.deepEqual(await request('GET', '/mobile-workspace/messages', other.token), []);
    await request('PATCH', `/mobile-workspace/messages/${message._id}/read`, other.token, {}, 404);
    await request('PATCH', `/mobile-workspace/messages/${message._id}/read`, employee.token, {});
    await request('PUT', `/mobile-workspace/admin/accounts/${parent.user._id}/access`, admin.token, { students: [] });
    await request('GET', `/mobile-workspace/students/${student.user._id}`, parent.token, undefined, 404);
    await request('POST', '/mobile-workspace/messages', parent.token, { recipient: employeeUser._id, body: 'Revoked relationship' }, 403);
    pass('employee tasks, manager scope, private messages and revoked access persist correctly');
    await request('PUT', '/mobile-workspace/preferences', student.token, { guardianName: 'Parent name', emergencyPhone: '12345', manager: true, referredBy: other.user._id });
    const prefs = await request('GET', '/mobile-workspace/preferences', student.token);
    assert.equal(prefs.guardianName, 'Parent name'); assert.equal(prefs.manager, undefined);
    assert.equal((await request('GET', '/mobile-workspace/referral', student.token)).linked, false);
    const referral = await request('GET', '/mobile-workspace/referral', other.token);
    await request('POST', '/mobile-workspace/referral', student.token, { code: referral.code }, 201);
    await request('POST', '/mobile-workspace/referral', student.token, { code: referral.code }, 409);
    await request('POST', '/mobile-workspace/admin/credits', student.token, { user: student.user._id, amount: 100, description: 'Forbidden' }, 403);
    await request('POST', '/mobile-workspace/admin/credits', admin.token, { user: student.user._id, amount: 25, description: 'Referral credit' }, 201);
    assert.equal((await request('GET', '/mobile-workspace/wallet', student.token)).balance, 25);
    assert.equal((await request('GET', '/mobile-workspace/wallet', other.token)).balance, 0);
    assert.equal((await request('GET', '/mobile-workspace/program-finder?budget=500', student.token)).length, 0);
    assert.equal((await request('GET', '/mobile-workspace/program-finder?budget=1500&degree=bachelor', student.token)).length, 2);
    pass('profile preferences, real referral attribution, wallet isolation and program filtering');

    await request('POST', '/mobile-security/email/request', student.token, {});
    const verifyCode = sentMail.at(-1).text.match(/\d{6}/)[0];
    await request('POST', '/mobile-security/email/confirm', student.token, { code: '000000' }, 400);
    await request('POST', '/mobile-security/email/confirm', student.token, { code: verifyCode });
    assert.equal((await request('GET', '/auth/me', student.token)).user.emailVerified, true);
    await request('POST', '/mobile-security/email/confirm', student.token, { code: verifyCode }, 400);
    const sessions = await request('GET', '/mobile-security/sessions', employee.token);
    assert.equal(sessions.length, 1); assert.equal(sessions[0].current, true); assert.equal(sessions[0].digest, undefined);
    await request('DELETE', `/mobile-security/sessions/${sessions[0]._id}`, parent.token, undefined, 404);
    await request('DELETE', `/mobile-security/sessions/${sessions[0]._id}`, employee.token);
    await request('GET', '/auth/me', employee.token, undefined, 401);
    const bypass = await fetch(`${origin}/auth/me`, { headers: { Authorization: `Bearer ${employee.token}` } });
    assert.equal(bypass.status, 401);
    pass('email codes are single-use and revoked sessions cannot bypass checks by omitting mobile headers');

    await request('POST', '/mobile-security/reset/request', null, { email: 'student@example.test' });
    const resetCode = sentMail.at(-1).text.match(/\d{6}/)[0];
    await request('POST', '/mobile-security/reset/confirm', null, { email: 'student@example.test', code: resetCode, password: 'NewPassword123!' });
    await request('GET', '/auth/me', student.token, undefined, 401);
    await request('POST', '/auth/login', null, { email: 'student@example.test', password: 'TestPassword123!' }, 401);
    const renewed = await request('POST', '/auth/login', null, { email: 'student@example.test', password: 'NewPassword123!' });
    await request('GET', '/auth/me', renewed.token);
    await request('POST', '/mobile-security/reset/confirm', null, { email: 'student@example.test', code: resetCode, password: 'AnotherPassword123!' }, 400);
    pass('password recovery invalidates old tokens immediately while allowing a fresh sign-in');
    await request('POST', '/mobile-security/two-factor/request', renewed.token, {});
    const securityCode = sentMail.at(-1).text.match(/\d{6}/)[0];
    await request('POST', '/mobile-security/two-factor/confirm', renewed.token, { code: securityCode, enabled: true });
    const challenge = await request('POST', '/auth/login', null, { email: 'student@example.test', password: 'NewPassword123!' }, 428);
    assert.equal(challenge.requiresTwoFactor, true); assert.equal(challenge.token, undefined);
    const loginCode = sentMail.at(-1).text.match(/\d{6}/)[0];
    await request('POST', '/auth/login', null, { email: 'student@example.test', password: 'NewPassword123!', twoFactorCode: '000000' }, 400);
    const protectedLogin = await request('POST', '/auth/login', null, { email: 'student@example.test', password: 'NewPassword123!', twoFactorCode: loginCode });
    await request('GET', '/auth/me', protectedLogin.token);
    await request('POST', '/auth/login', null, { email: 'student@example.test', password: 'NewPassword123!', twoFactorCode: loginCode }, 400);
    await request('PUT', '/students/profile', protectedLogin.token, { email: 'takeover@example.test' }, 400);
    await request('POST', '/mobile-security/two-factor/confirm', protectedLogin.token, { code: securityCode, enabled: false }, 400);
    pass('two-factor login requires a fresh email code and cannot be disabled with a reused code');
    const report = { passed, database: 'real isolated localhost MongoDB', storage: 'Cloudinary adapter mocked; multipart and persistence real', completedAt: new Date().toISOString() };
    fs.writeFileSync(path.join(__dirname, 'live-test-results.json'), JSON.stringify(report, null, 2));
    console.log(`SUCCESS: ${passed} live integration scenarios passed.`);
  } catch (error) {
    console.error('FAIL:', error.stack || error); process.exitCode = 1;
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  }
})();
