const { test } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('private upload, scoped access, expiration and public signer isolation', async () => {
  Object.assign(process.env, { JWT_SECRET: 'private-doc-test-only', CLOUDINARY_CLOUD_NAME: 'test-cloud', CLOUDINARY_API_KEY: '123456', CLOUDINARY_API_SECRET: 'test-only-secret' });
  let mongo, server, originalUpload;
  try {
    mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
    await mongoose.connect(mongo.getUri());
    const { cloudinary } = require('../src/config/cloudinary');
    originalUpload = cloudinary.uploader.upload_stream;
    cloudinary.uploader.upload_stream = (options, callback) => {
      assert.equal(options.type, 'authenticated'); assert.equal(options.resource_type, 'raw');
      assert.ok(options.public_id.startsWith('study-birds/private-documents/'));
      return { end(buffer) { callback(null, { public_id: options.public_id, type: 'authenticated', bytes: buffer.length }); } };
    };
    const app = require('../src/app');
    const User = require('../src/models/User');
    const Document = require('../src/models/Document');
    const Application = require('../src/models/Application');
    const ParentLink = require('../src/models/ParentLink');
    const student = await User.create({ name: 'Student', email: 'student@example.test', role: 'student' });
    const other = await User.create({ name: 'Other', email: 'other@example.test', role: 'student' });
    const parent = await User.create({ name: 'Parent', email: 'parent@example.test', role: 'parent' });
    const staff = await User.create({ name: 'Staff', email: 'staff@example.test', role: 'employee', permissions: ['applications'] });
    const unrelatedStaff = await User.create({ name: 'Catalog', email: 'catalog@example.test', role: 'employee', permissions: ['programs'] });
    const universityId = new mongoose.Types.ObjectId();
    const university = await User.create({ name: 'University', email: 'uni@example.test', role: 'university', linkedUniversity: universityId });
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    const form = new FormData(); form.append('type', 'passport'); form.append('file', new Blob(['%PDF-1.4\ntest document\n%%EOF'], { type: 'application/pdf' }), 'passport.pdf');
    const uploaded = await fetch(base + '/students/documents', { method: 'POST', headers: { Authorization: `Bearer ${token(student)}` }, body: form });
    assert.equal(uploaded.status, 201);
    const doc = await uploaded.json();
    assert.equal(doc.storage, undefined); assert.equal(doc.filePath, `/api/documents/${doc._id}/access`);
    assert.equal((await Document.findById(doc._id)).storage, undefined);
    assert.equal((await Document.findById(doc._id).select('+storage')).storage.deliveryType, 'authenticated');
    async function access(user, expected) {
      const result = await fetch(base + `/documents/${doc._id}/access`, { method: 'POST', headers: user ? { Authorization: `Bearer ${token(user)}` } : {} });
      assert.equal(result.status, expected); return result;
    }
    await access(null, 401); await access(other, 404); await access(unrelatedStaff, 404); await access(parent, 404); await access(university, 404);
    const own = await access(student, 200);
    assert.equal(own.headers.get('cache-control'), 'no-store');
    const link = await own.json(); const url = new URL(link.url);
    assert.equal(url.hostname, 'api.cloudinary.com'); assert.ok(url.pathname.includes('/raw/download'));
    assert.equal(url.searchParams.get('type'), 'authenticated'); assert.equal(url.searchParams.get('attachment'), 'true');
    assert.ok(link.expiresAt > Date.now() / 1000 + 110 && link.expiresAt <= Date.now() / 1000 + 120);
    assert.equal(Number(url.searchParams.get('expires_at')), link.expiresAt); assert.ok(url.searchParams.get('signature'));
    await access(staff, 200);
    const parentLink = await ParentLink.create({ parent: parent._id, student: student._id, status: 'approved' });
    await access(parent, 200); parentLink.status = 'rejected'; await parentLink.save(); await access(parent, 404);
    const application = await Application.create({ student: student._id, university: universityId, program: new mongoose.Types.ObjectId(), documents: [doc._id] });
    await access(university, 200); application.documents = []; await application.save(); await access(university, 404);
    const Invoice = require('../src/models/Invoice');
    const PaymentProof = require('../src/models/PaymentProof');
    const finance = await User.create({ name: 'Finance', email: 'finance@example.test', role: 'employee', permissions: ['student-financials'] });
    const invoice = await Invoice.create({ student: student._id, invoiceNumber: 'INV-private', description: 'Test invoice', amount: 100 });
    const proofForm = new FormData(); proofForm.append('file', new Blob(['%PDF-1.4\ntest receipt\n%%EOF'], { type: 'application/pdf' }), 'receipt.pdf');
    const proofResponse = await fetch(base + `/students/financials/invoices/${invoice._id}/payment-proof`, { method: 'POST', headers: { Authorization: `Bearer ${token(student)}` }, body: proofForm });
    assert.equal(proofResponse.status, 201);
    const proof = await proofResponse.json();
    assert.equal(proof.storage, undefined);
    assert.equal(proof.filePath, `/api/payment-proofs/${proof._id}/access`);
    assert.equal((await PaymentProof.findById(proof._id)).storage, undefined);
    for (const [actor, expected] of [[null,401],[student,200],[other,404],[finance,200],[staff,404],[university,404],[parent,404]]) {
      const result = await fetch(base + `/payment-proofs/${proof._id}/access`, { method: 'POST', headers: actor ? { Authorization: `Bearer ${token(actor)}` } : {} });
      assert.equal(result.status, expected);
      if (expected === 200) { assert.equal(result.headers.get('cache-control'), 'no-store'); assert.ok((await result.json()).expiresAt > Date.now()/1000); }
    }
    parentLink.status = 'approved'; await parentLink.save();
    assert.equal((await fetch(base + `/payment-proofs/${proof._id}/access`, { method: 'POST', headers: { Authorization: `Bearer ${token(parent)}` } })).status, 200);
    assert.equal((await Invoice.findById(invoice._id)).status, 'pending-confirmation');
    const SupportTicket = require('../src/models/SupportTicket');
    const support = await User.create({ name: 'Support', email: 'support@example.test', role: 'employee', permissions: ['support'] });
    const partner = await User.create({ name: 'Partner', email: 'partner@example.test', role: 'partner' });
    const admin = await User.create({ name: 'Admin', email: 'admin@example.test', role: 'admin' });
    for (const [owner, route] of [[student, '/students/support-tickets'], [partner, '/partners/tickets']]) {
      const form = new FormData(); form.append('subject', 'Help'); form.append('message', 'Please review');
      form.append('file', new Blob(['%PDF-1.4\nsupport attachment\n%%EOF'], { type: 'application/pdf' }), 'help.pdf');
      const response = await fetch(base + route, { method: 'POST', headers: { Authorization: `Bearer ${token(owner)}` }, body: form });
      assert.equal(response.status, 201);
      const ticket = await response.json();
      assert.equal(ticket.attachmentStorage, undefined);
      assert.equal(ticket.attachment.filePath, `/api/support-attachments/${ticket._id}/access`);
      assert.equal((await SupportTicket.findById(ticket._id)).attachmentStorage, undefined);
      for (const [actor, expected] of [[null,401],[owner,200],[support,200],[admin,200],[other,404],[finance,404],[staff,404],[university,404],[parent,404]]) {
        const response = await fetch(base + `/support-attachments/${ticket._id}/access`, { method: 'POST', headers: actor ? { Authorization: `Bearer ${token(actor)}` } : {} });
        assert.equal(response.status, expected);
        if (expected === 200) { assert.equal(response.headers.get('cache-control'), 'no-store'); assert.ok((await response.json()).expiresAt > Date.now()/1000); }
      }
      await SupportTicket.updateOne({ _id: ticket._id }, { $unset: { attachmentStorage: 1 } });
      assert.equal((await fetch(base + `/support-attachments/${ticket._id}/access`, { method: 'POST', headers: { Authorization: `Bearer ${token(owner)}` } })).status, 409);
    }
    for (const type of ['authenticated', 'private', 'upload']) {
      const fake = `https://res.cloudinary.com/test-cloud/raw/${type}/v1/study-birds/private-documents/example.pdf`;
      const response = await fetch(base + '/content/file-open?url=' + encodeURIComponent(fake), { redirect: 'manual' });
      assert.equal(response.status, 403);
    }
  } finally {
    if (originalUpload) require('../src/config/cloudinary').cloudinary.uploader.upload_stream = originalUpload;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); if (mongo) await mongo.stop();
  }
});
