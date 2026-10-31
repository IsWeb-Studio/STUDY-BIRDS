const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('the first admin invoice and its notification are readable without a second invoice', async () => {
  process.env.JWT_SECRET = 'first-invoice-regression';
  Object.assign(process.env, { CLOUDINARY_CLOUD_NAME: 'test-cloud', CLOUDINARY_API_KEY: '123456', CLOUDINARY_API_SECRET: 'test-only-secret' });
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Invoice = require('../src/models/Invoice');
    const Notification = require('../src/models/Notification');
    const student = await User.create({ name: 'Student', email: 'first@test.example', role: 'student' });
    const other = await User.create({ name: 'Other', email: 'other@test.example', role: 'student' });
    const admin = await User.create({ name: 'Admin', email: 'admin@test.example', role: 'admin' });
    require('../src/config/cloudinary').cloudinary.uploader.upload_stream = (options, callback) => ({
      end(buffer) { callback(null, { public_id: options.public_id, type: 'authenticated', bytes: buffer.length }); },
    });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    async function call(method, endpoint, user, body) {
      const res = await fetch(base + endpoint, { method, headers: { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
      const data = await res.json(); assert.equal(res.ok, true, JSON.stringify(data)); return data;
    }
    assert.equal((await call('GET', '/students/financials', student)).invoices.length, 0);
    const invoice = await call('POST', '/admin/student-financials/invoices', admin, {
      studentId: String(student._id), invoiceNumber: 'FIRST-1', description: 'First invoice', amount: 100,
    });
    const fin = await call('GET', '/students/financials', student);
    assert.equal(fin.invoices.length, 1); assert.equal(fin.invoices[0]._id, invoice._id);
    assert.equal(fin.summary.outstandingAmount, 100);
    assert.equal((await call('GET', '/students/financials', other)).invoices.length, 0);
    const notice = await Notification.findOne({ user: student._id });
    assert.equal(notice.link, `/student/payments/${invoice._id}`);
    const proof = new FormData();
    proof.append('file', new Blob(['%PDF-1.4\nFirst payment\n%%EOF'], { type: 'application/pdf' }), 'receipt.pdf');
    proof.append('amount', '100');
    const paid = await fetch(`${base}/students/financials/invoices/${invoice._id}/payment-proof`, {
      method: 'POST', headers: { Authorization: `Bearer ${jwt.sign({ userId: student._id }, process.env.JWT_SECRET)}` }, body: proof,
    });
    const payment = await paid.json(); assert.equal(paid.status, 201, JSON.stringify(payment));
    assert.equal((await call('GET', '/students/financials', student)).invoices[0].status, 'pending-confirmation');
    assert.equal(await Invoice.countDocuments({ student: student._id }), 1);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
