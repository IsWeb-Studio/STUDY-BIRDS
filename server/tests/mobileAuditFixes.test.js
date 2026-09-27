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
    await Request.updateOne({ _id: request._id }, { $set: { staffNote: 'PRIVATE', statusHistory: [{ status: 'assigned', note: 'PRIVATE HISTORY', changedBy: employee._id }] } });
    await call('GET', `/service-requests/${request._id}`, parent, undefined, 403);
    await call('GET', `/service-requests/${request._id}`, unauthorized, undefined, 403);
    await call('GET', `/service-requests/${request._id}`, other, undefined, 404);
    const mine = await call('GET', '/service-requests/mine', student);
    assert.equal(JSON.stringify(mine).includes('PRIVATE'), false);
    assert.equal((await call('GET', `/service-requests/${request._id}`, employee)).staffNote, 'PRIVATE');
    await call('PATCH', `/service-requests/${request._id}`, employee, { assignedTo: parent._id }, 400);
    await call('PATCH', `/service-requests/${request._id}`, employee, { status: 'invented' }, 400);

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
