const { test } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('central document library: reuse, races, failures, versions and tenant permissions', async t => {
  Object.assign(process.env, { JWT_SECRET: 'document-library-test-only', CLOUDINARY_CLOUD_NAME: 'test-cloud',
    CLOUDINARY_API_KEY: '123456', CLOUDINARY_API_SECRET: 'test-only-secret' });
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  const { cloudinary } = require('../src/config/cloudinary');
  const original = cloudinary.uploader.upload_stream;
  let writes = 0, failNext = false;
  const objects = new Map();
  cloudinary.uploader.upload_stream = (options, callback) => ({ end(buffer) {
    assert.equal(options.type, 'authenticated');
    assert.equal(options.overwrite, false);
    setTimeout(() => {
      if (failNext) { failNext = false; callback(new Error('Simulated storage interruption')); return; }
      const existing = objects.has(options.public_id);
      if (!existing) { writes++; objects.set(options.public_id, buffer); }
      callback(null, { public_id: options.public_id, type: 'authenticated', existing, bytes: buffer.length });
    }, 100);
  } });
  try {
    await mongoose.connect(mongo.getUri());
    const Document = require('../src/models/Document');
    const User = require('../src/models/User');
    const Application = require('../src/models/Application');
    const service = await require('../src/models/OurService').create({ title: 'Visa help' });
    const { hashFile } = require('../src/utils/documentLibrary');
    const student = await User.create({ name: 'Student', email: 'library@example.test', role: 'student' });
    const other = await User.create({ name: 'Other', email: 'other-library@example.test', role: 'student' });
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    const app = require('../src/app');
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    const request = (route, user = student, body, method = 'POST') => fetch(base + route, { method,
      headers: { Authorization: `Bearer ${token(user)}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}) });
    const bytes = '%PDF-1.4\npassport fixture\n%%EOF';
    const upload = (content = bytes, user = student, extra = {}, name = 'passport.pdf') => {
      const form = new FormData(); form.append('type', 'passport');
      for (const [key, value] of Object.entries(extra)) form.append(key, value);
      form.append('file', new Blob([content], { type: 'application/pdf' }), name);
      return fetch(base + '/students/documents', { method: 'POST', headers: { Authorization: `Bearer ${token(user)}` }, body: form });
    };
    let document, replacement;
    await t.test('upload once and identical retry with a renamed file reuses the record', async () => {
      const first = await upload(); assert.equal(first.status, 201); document = await first.json();
      assert.equal(document.storage, undefined); assert.equal(document.fileHash, hashFile(Buffer.from(bytes)));
      const retry = await upload(bytes, student, {}, 'different-name.pdf');
      assert.equal(retry.status, 200); assert.equal((await retry.json())._id, document._id);
      assert.equal(writes, 1); assert.equal(await Document.countDocuments(), 1);
    });
    await t.test('simultaneous identical uploads create one object and one document', async () => {
      const content = bytes + '\nsimultaneous';
      const responses = await Promise.all([upload(content), upload(content)]);
      assert.deepEqual(responses.map(r => r.status).sort(), [200, 201]);
      const [a, b] = await Promise.all(responses.map(r => r.json())); assert.equal(a._id, b._id);
      assert.equal(await Document.countDocuments({ fileHash: hashFile(Buffer.from(content)) }), 1);
      assert.equal(writes, 2);
    });
    await t.test('failed storage write has no uploaded record and retry succeeds once', async () => {
      const content = bytes + '\ninterrupted'; failNext = true;
      assert.equal((await upload(content)).status, 500);
      assert.equal(await Document.countDocuments({ fileHash: hashFile(Buffer.from(content)) }), 0);
      assert.equal((await upload(content)).status, 201); assert.equal((await upload(content)).status, 200);
      assert.equal(writes, 3);
    });
    await t.test('library lookup and download access never expose another account', async () => {
      const body = { fileHash: document.fileHash, size: Buffer.byteLength(bytes), type: 'passport' };
      assert.equal((await (await request('/students/documents/lookup', student, body)).json()).document._id, document._id);
      assert.equal((await (await request('/students/documents/lookup', other, body)).json()).document, null);
      assert.equal((await request(`/documents/${document._id}/access`, other)).status, 404);
      assert.equal((await request(`/documents/${document._id}/access`, student)).status, 200);
      assert.equal((await upload(bytes, other, { replaces: document._id })).status, 404);
    });
    await t.test('existing document attaches by reference to a service without another storage write', async () => {
      const before = writes;
      const response = await request('/service-requests', student, { serviceId: String(service._id), documentIds: [document._id] });
      assert.equal(response.status, 201); const row = await response.json();
      assert.equal(row.documents[0].document, document._id); assert.equal(writes, before);
      const foreign = await request('/service-requests', other, { serviceId: String(service._id), documentIds: [document._id] });
      assert.equal(foreign.status, 400);
    });
    await t.test('new program request uses saved IDs and submitted requests retain those IDs', async () => {
      const country = await require('../src/models/Country').create({ name: 'Test country', code: 'ZZ' });
      const university = await require('../src/models/University').create({ name: 'Test university', country: country._id });
      const program = await require('../src/models/Program').create({ title: 'Test program', university: university._id,
        degreeLevel: 'bachelor', fieldOfStudy: 'Science', requiredDocumentTypes: ['passport'] });
      const before = writes;
      const response = await request('/applications', student, { programId: String(program._id), documentIds: [document._id] });
      assert.equal(response.status, 201);
      const row = await response.json(); assert.equal(row.documents[0]._id, document._id); assert.equal(writes, before);
      const mine = await (await request('/students/applications', student, null, 'GET')).json();
      assert.equal(mine.find(item => item._id === row._id).documents[0]._id, document._id);
    });
    await t.test('replacement retains previous application references and history', async () => {
      const application = await Application.create({ student: student._id, program: new mongoose.Types.ObjectId(),
        university: new mongoose.Types.ObjectId(), documents: [document._id] });
      const response = await upload(bytes + '\nrenewed', student, { replaces: document._id });
      assert.equal(response.status, 201); replacement = await response.json();
      assert.equal(replacement.version, 2); assert.equal(replacement.replaces, document._id);
      assert.equal(String((await Document.findById(document._id)).supersededBy), replacement._id);
      assert.equal(String((await Application.findById(application._id)).documents[0]), document._id);
      assert.equal((await upload(bytes + '\nrenewed', student, { replaces: document._id })).status, 200);
    });
    await t.test('archive preserves the physical object and existing attachments', async () => {
      const before = writes;
      assert.equal((await request(`/students/documents/${replacement._id}/archive`, student, {}, 'PATCH')).status, 200);
      assert.ok((await Document.findById(replacement._id)).archivedAt);
      assert.equal((await request(`/documents/${replacement._id}/access`, student)).status, 200);
      assert.equal(writes, before);
    });
    await t.test('retry after archival restores the same current record without another object', async () => {
      const before = writes;
      const response = await upload(bytes + '\nrenewed');
      assert.equal(response.status, 200); assert.equal((await response.json())._id, replacement._id);
      assert.equal((await Document.findById(replacement._id)).archivedAt, undefined);
      assert.equal(writes, before);
    });
    await t.test('agent contact documents are private and scoped to their owning agent', async () => {
      const agent = await User.create({ name: 'Agent', email: 'agent-library@example.test', role: 'partner' });
      const otherAgent = await User.create({ name: 'Other agent', email: 'other-agent-library@example.test', role: 'partner' });
      const contact = await require('../src/models/AgentStudent').create({ agent: agent._id, name: 'Contact',
        email: 'contact-library@example.test', phone: '+905551234567' });
      async function agentUpload() {
        const form = new FormData(); form.append('type', 'passport'); form.append('label', 'Passport');
        form.append('file', new Blob([bytes], { type: 'application/pdf' }), 'passport.pdf');
        return fetch(base + `/partners/students/${contact._id}/documents`, { method: 'POST',
          headers: { Authorization: `Bearer ${token(agent)}` }, body: form });
      }
      const first = await agentUpload(); assert.equal(first.status, 201); const row = await first.json();
      const id = row.documents[0].document;
      assert.equal((await agentUpload()).status, 200);
      assert.equal((await require('../src/models/AgentStudent').findById(contact._id)).documents.length, 1);
      assert.equal((await request(`/documents/${id}/access`, agent)).status, 200);
      assert.equal((await request(`/documents/${id}/access`, otherAgent)).status, 404);
      assert.equal((await request(`/documents/${id}/access`, student)).status, 404);
    });
    await t.test('retry after DB interruption reuses the already stored object', async () => {
      const before = writes, originalUpdate = Document.findOneAndUpdate;
      const content = bytes + '\nDB interruption';
      Document.findOneAndUpdate = function () { Document.findOneAndUpdate = originalUpdate; throw new Error('Simulated lost DB connection'); };
      try { assert.equal((await upload(content)).status, 500); }
      finally { Document.findOneAndUpdate = originalUpdate; }
      assert.equal(await Document.countDocuments({ fileHash: hashFile(Buffer.from(content)) }), 0);
      assert.equal((await upload(content)).status, 201);
      assert.equal(await Document.countDocuments({ fileHash: hashFile(Buffer.from(content)) }), 1);
      assert.equal(writes, before + 1);
    });
  } finally {
    cloudinary.uploader.upload_stream = original;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
