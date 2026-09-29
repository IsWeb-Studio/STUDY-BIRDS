const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const crypto = require('node:crypto');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('mobile audit: service isolation, profile persistence, insurance and signed payments', async () => {
  process.env.JWT_SECRET = 'isolated-mobile-audit';
  process.env.STRIPE_SECRET_KEY = 'sk_test_mock';
  process.env.STRIPE_WEBHOOK_SECRET = 'whsec_local_only';
  delete process.env.ONESIGNAL_REST_API_KEY;
  const originalFetch = global.fetch;
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const app = require('../src/app');
    const User = require('../src/models/User');
    const Service = require('../src/models/OurService');
    const Request = require('../src/models/ServiceRequest');
    const Invoice = require('../src/models/Invoice');
    const Profile = require('../src/models/StudentProfile');
    await Promise.all(Object.values(mongoose.models).map(model => model.init()));
    const student = await User.create({ name: 'Student', email: 'student@audit.test' });
    const other = await User.create({ name: 'Other', email: 'other@audit.test' });
    const parent = await User.create({ name: 'Parent', email: 'parent@audit.test', role: 'parent' });
    const employee = await User.create({ name: 'Staff', email: 'staff@audit.test', role: 'employee', permissions: ['services'] });
    const unauthorized = await User.create({ name: 'Admissions', email: 'admissions@audit.test', role: 'employee', permissions: ['applications'] });
    const finance = await User.create({ name: 'Finance', email: 'finance@audit.test', role: 'employee', permissions: ['student-financials'] });
    const service = await Service.create({ title: 'Translation' });
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    async function call(method, endpoint, user, body, status = 200) {
      const result = await originalFetch(base + endpoint, { method, headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${token(user)}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
      const data = await result.json();
      assert.equal(result.status, status, `${endpoint}: ${JSON.stringify(data)}`);
      return data;
    }
    const request = await call('POST', '/service-requests', student, { serviceId: service._id }, 201);
    const rewardPath = '/admin/student-financials/reward-rules';
    const ruleBody = { event: 'referral-qualified', title: 'Successful referral', points: 40, enabled: false };
    await call('POST', rewardPath, student, ruleBody, 403);
    await call('POST', rewardPath, unauthorized, ruleBody, 403);
    await call('POST', rewardPath, finance, { ...ruleBody, points: 1.5 }, 400);
    const rule = await call('POST', rewardPath, finance, ruleBody, 201);
    await require('../src/models/StudentReferral').create({ referrer: student._id, referredUser: other._id, code: 'TEST', status: 'qualified' });
    await require('../src/models/StudentWalletEntry').create({ student: student._id, direction: 'credit', kind: 'adjustment', amount: 123 });
    assert.equal((await call('GET', '/students/rewards', student)).totalPoints, 0, 'disabled rules and wallet money do not grant points');
    await call('PUT', `${rewardPath}/${rule._id}`, finance, { ...ruleBody, enabled: true });
    const results = await Promise.all([call('GET', '/students/rewards', student), call('GET', '/students/rewards', student)]);
    for (const result of results) assert.equal(result.totalPoints, 40);
    await call('PUT', `${rewardPath}/${rule._id}`, finance, { ...ruleBody, points: 80, enabled: true });
    const rewards = await call('GET', '/students/rewards', student);
    assert.equal(rewards.totalPoints, 40, 'rule edits do not rewrite historical awards');
    assert.equal(rewards.entries.length, 1);
    assert.equal((await call('GET', '/students/rewards', other)).totalPoints, 0);
    const alumni = await call('PUT', '/alumni/me', student, { university: 'Test University', country: 'Turkey', graduationYear: 2020 });
    assert.equal(alumni.isPublic, false, 'new profiles are private without explicit consent');
    assert.equal((await call('GET', '/alumni', other)).length, 0);
    await call('GET', `/alumni/${student._id}`, other, undefined, 404);
    await call('PUT', '/alumni/me', student, { linkedinUrl: 'https://evil.example/test' }, 400);
    await call('PUT', '/alumni/me', student, { country: { $ne: null } }, 400);
    await call('PUT', '/alumni/me', student, { graduationYear: 2999 }, 400);
    await call('PUT', '/alumni/me', parent, { isPublic: true }, 403);
    await call('PUT', '/alumni/me', student, { isPublic: true, openToMentoring: true });
    assert.equal((await call('GET', '/alumni?mentoring=true', other)).length, 1);
    assert.equal((await call('GET', '/alumni?country=.*', other)).length, 0, 'search escapes regex metacharacters');
    await call('PUT', '/alumni/me', student, { isPublic: false });
    assert.equal((await call('GET', '/alumni', other)).length, 0);
    const publisher = await User.create({ name: 'Publisher', email: 'publisher@audit.test', role: 'employee', permissions: ['community'] });
    const listingPath = '/admin/community-posts/listings';
    const listingBody = { kind: 'offer', title: 'Student discount', terms: 'Valid student card', published: false, url: 'https://example.test/offer' };
    await call('POST', listingPath, student, listingBody, 403);
    await call('POST', listingPath, unauthorized, listingBody, 403);
    await call('POST', listingPath, publisher, { ...listingBody, url: 'javascript:alert(1)' }, 400);
    const listing = await call('POST', listingPath, publisher, listingBody, 201);
    assert.equal((await call('GET', '/students/listings?kind=offer', student)).length, 0);
    await call('PUT', `${listingPath}/${listing._id}`, publisher, { ...listingBody, published: true, expiresAt: '2000-01-01' });
    assert.equal((await call('GET', '/students/listings?kind=offer', student)).length, 0);
    await call('PUT', `${listingPath}/${listing._id}`, publisher, { ...listingBody, published: true, validFrom: '2099-01-01' });
    assert.equal((await call('GET', '/students/listings?kind=offer', student)).length, 0);
    await call('PUT', `${listingPath}/${listing._id}`, publisher, { ...listingBody, published: true });
    const activeOffers = await call('GET', '/students/listings?kind=offer', student);
    assert.equal(activeOffers.length, 1);
    assert.equal(activeOffers[0].terms, listingBody.terms);
    assert.equal(activeOffers[0].updatedBy, undefined);
    assert.equal((await call('GET', '/students/listings?kind=opportunity', student)).length, 0);
    await Request.updateOne({ _id: request._id }, { $set: { staffNote: 'PRIVATE', statusHistory: [{ status: 'assigned', note: 'PRIVATE HISTORY', changedBy: employee._id }] } });
    await call('GET', `/service-requests/${request._id}`, parent, undefined, 403);
    await call('GET', `/service-requests/${request._id}`, unauthorized, undefined, 403);
    await call('GET', `/service-requests/${request._id}`, other, undefined, 404);
    const mine = await call('GET', '/service-requests/mine', student);
    assert.equal(JSON.stringify(mine).includes('PRIVATE'), false);
    assert.equal((await call('GET', `/service-requests/${request._id}`, employee)).staffNote, 'PRIVATE');
    await call('PATCH', `/service-requests/${request._id}`, employee, { assignedTo: parent._id }, 400);
    await call('PATCH', `/service-requests/${request._id}`, employee, { status: 'invented' }, 400);
    const updatedRequest = await call('PATCH', `/service-requests/${request._id}`, employee, { status: 'in-progress', expectedVersion: 0 });
    assert.equal(updatedRequest.__v, 1);
    await call('PATCH', `/service-requests/${request._id}`, employee, { status: 'completed', expectedVersion: 0 }, 409);
    assert.equal((await Request.findById(request._id)).status, 'in-progress');
    const details = { title: 'Insurance service', priceDescription: '100 USD', estimatedDuration: '3 days', requirementsText: 'Active student', documentsText: 'Passport' };
    const published = await call('POST', '/admin/our-services', employee, details, 201);
    assert.equal(published.priceDescription, details.priceDescription);
    const edited = await call('PUT', `/admin/our-services/${published._id}`, employee, { title: details.title });
    assert.equal(edited.documentsText, details.documentsText);
    await call('PUT', `/admin/our-services/${published._id}`, employee, { priceDescription: { $ne: null } }, 400);

    const contacts = { parentInfo: { name: 'Parent Name', phone: '+90555123', relationship: 'mother' }, emergencyContact: { name: 'Emergency', phone: '555', relationship: 'sister' }, nativeLanguage: 'Arabic', otherLanguages: ['English', 'English'] };
    const saved = await call('PUT', '/students/profile', student, { ...contacts, applicationStage: 'final-accepted' });
    assert.equal(saved.parentInfo.name, 'Parent Name');
    assert.equal(saved.emergencyContact.phone, '555');
    assert.deepEqual(saved.otherLanguages, ['English']);
    assert.notEqual(saved.applicationStage, 'final-accepted');
    assert.equal((await Profile.findOne({ user: student._id })).nativeLanguage, 'Arabic');
    await call('PUT', '/students/profile', student, { parentInfo: { name: { $ne: null } } }, 400);

    assert.equal(await call('GET', '/students/insurance', student), null);
    await call('PUT', `/admin/students/${student._id}/insurance`, unauthorized, { provider: 'No' }, 403);
    await call('PUT', `/admin/students/${student._id}/insurance`, employee, { provider: 'Provider', status: 'active', startDate: '2026-01-01', endDate: '2099-01-01' });
    assert.equal((await call('GET', '/students/insurance', student)).provider, 'Provider');
    assert.equal(await call('GET', '/students/insurance', other), null);
    await call('PUT', `/admin/students/${student._id}/insurance`, employee, { endDate: '2020-01-01' }, 400);
    await call('PUT', `/admin/students/${student._id}/equivalency`, employee, { status: 'submitted', authority: 'Test authority', requiredDocuments: ['Diploma'] });
    assert.equal((await call('GET', '/students/equivalency', student)).status, 'submitted');

    const invoice = await Invoice.create({ student: student._id, invoiceNumber: 'AUDIT-1', description: 'Tuition', amount: 12.34, currency: 'EUR' });
    let stripeCalls = 0;
    global.fetch = async (url, init) => {
      if (String(url).startsWith('https://api.stripe.com/')) {
        stripeCalls++;
        const params = new URLSearchParams(init.body);
        assert.equal(params.get('line_items[0][price_data][currency]'), 'eur');
        assert.equal(params.get('line_items[0][price_data][unit_amount]'), '1234');
        return new Response(JSON.stringify({ id: 'cs_audit', url: 'https://checkout.stripe.com/c/pay/cs_audit' }));
      }
      return originalFetch(url, init);
    };
    await call('POST', '/payments/stripe/checkout', other, { invoiceId: invoice._id }, 404);
    await call('POST', '/payments/stripe/checkout', student, { invoiceId: invoice._id });
    await call('POST', '/payments/stripe/checkout', student, { invoiceId: invoice._id });
    assert.equal(stripeCalls, 1);
    const event = { type: 'checkout.session.completed', data: { object: { id: 'cs_audit', payment_status: 'paid', amount_total: 1234, currency: 'eur', metadata: { invoiceId: String(invoice._id), studentId: String(student._id) } } } };
    async function webhook(value, signature = true, expected = 200) {
      // Preserve whitespace deliberately: JSON reserialization cannot verify this signature.
      const raw = JSON.stringify(value, null, 2);
      const timestamp = String(Math.floor(Date.now() / 1000));
      const digest = crypto.createHmac('sha256', process.env.STRIPE_WEBHOOK_SECRET).update(`${timestamp}.${raw}`).digest('hex');
      const response = await originalFetch(base + '/payments/stripe/webhook', { method: 'POST', headers: { 'Content-Type': 'application/json', 'stripe-signature': `t=${timestamp},v1=${signature ? digest : '0'.repeat(64)}` }, body: raw });
      assert.equal(response.status, expected, await response.text());
    }
    await webhook(event, false, 400);
    await webhook({ ...event, data: { object: { ...event.data.object, amount_total: 1 } } });
    assert.equal((await Invoice.findById(invoice._id)).status, 'unpaid');
    await webhook(event);
    await webhook(event);
    assert.equal((await Invoice.findById(invoice._id)).status, 'paid');
    const Notification = require('../src/models/Notification');
    assert.equal(await Notification.countDocuments({ user: student._id, title: 'تم استلام الدفع بنجاح' }), 1);
  } finally {
    global.fetch = originalFetch;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect();
    await mongo.stop();
  }
});
