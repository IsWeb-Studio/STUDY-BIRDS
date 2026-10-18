const { test } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('passport OCR persists automatically once and replacements preserve it', async () => {
  Object.assign(process.env, { JWT_SECRET: 'passport-test-only', CLOUDINARY_CLOUD_NAME: 'test-cloud',
    CLOUDINARY_API_KEY: '123456', CLOUDINARY_API_SECRET: 'test-only-secret' });
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  const { cloudinary } = require('../src/config/cloudinary');
  const original = cloudinary.uploader.upload_stream;
  let fail = true, server;
  cloudinary.uploader.upload_stream = (options, callback) => ({ end(buffer) {
    if (fail) return callback(new Error('Storage unavailable'));
    callback(null, { public_id: options.public_id, type: 'authenticated', bytes: buffer.length });
  } });
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Profile = require('../src/models/StudentProfile');
    const Document = require('../src/models/Document');
    await Profile.init();
    const user = await User.create({ name: 'Student', email: 'passport@example.test', role: 'student' });
    const app = require('../src/app');
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api/students`;
    const headers = { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` };
    const fields = { number: 'ABC123', name: 'FIRST PERSON', nationality: 'UTO', birth: '1990-01-02', expiry: '2035-01-02', sex: 'F' };
    const upload = async (data, previous, includeMetadata = true) => {
      const form = new FormData(); form.append('type', 'passport');
      if (previous) form.append('replaces', previous);
      if (includeMetadata) form.append('passportReview', JSON.stringify({ extracted: data,
        reviewed: { ...data, number: 'EDITED' }, clientReportedMrzChecksPassed: true }));
      form.append('file', new Blob([`%PDF-1.4\n${data.number}\n%%EOF`], { type: 'application/pdf' }), 'passport.pdf');
      return fetch(base + '/documents', { method: 'POST', headers, body: form });
    };
    assert.equal((await upload(fields)).status, 500);
    assert.equal(await Profile.countDocuments({ user: user._id }), 0);
    fail = false;
    const first = await upload(fields, null, false); assert.equal(first.status, 201);
    const document = await first.json();
    // Rescanning a legacy file fills missing metadata without duplicate storage.
    assert.equal((await upload(fields)).status, 200);
    const read = async () => (await fetch(base + '/profile', { headers })).json();
    let profile = await read();
    assert.equal(profile.passportNumber, fields.number);
    assert.equal(profile.passportIdentity.name, fields.name);
    assert.equal(profile.passportIdentity.number, fields.number); // original OCR, never user corrections
    assert.equal(profile.dateOfBirth.slice(0, 10), fields.birth);
    const snapshot = profile.passportIdentity;
    const changed = { ...fields, number: 'XYZ456', name: 'ANOTHER PERSON', birth: '1995-05-06' };
    assert.equal((await upload(changed, document._id)).status, 201);
    profile = await read(); assert.deepEqual(profile.passportIdentity, snapshot);
    assert.equal(profile.passportNumber, fields.number);
    await fetch(base + '/profile', { method: 'PUT', headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ passportNumber: 'MANUAL', dateOfBirth: '2000-01-01', passportIdentity: changed }) });
    profile = await read(); assert.deepEqual(profile.passportIdentity, snapshot);
    assert.equal(profile.passportNumber, fields.number);
    // Recover interrupted snapshot persistence / migrate existing uploaded passports.
    await Profile.updateOne({ user: user._id }, { $unset: { passportIdentity: 1 } });
    profile = await read(); assert.equal(profile.passportIdentity.document, document._id);
    assert.equal(profile.passportIdentity.number, fields.number);
    assert.equal((await Document.findById(document._id)).status, 'pending');
  } finally {
    cloudinary.uploader.upload_stream = original;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
