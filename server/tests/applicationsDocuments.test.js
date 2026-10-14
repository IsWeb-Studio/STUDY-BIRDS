const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('program details, application cards, document versions/translations and request notices', async () => {
  Object.assign(process.env, { JWT_SECRET: 'apps-docs-test', CLOUDINARY_CLOUD_NAME: 'test-cloud', CLOUDINARY_API_KEY: '123456', CLOUDINARY_API_SECRET: 'test-only-secret' });
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server, originalUpload;
  try {
    await mongoose.connect(mongo.getUri());
    const { cloudinary } = require('../src/config/cloudinary');
    originalUpload = cloudinary.uploader.upload_stream;
    let uploads = 0;
    cloudinary.uploader.upload_stream = (options, callback) => ({ end(buffer) { uploads += 1; callback(null, { public_id: options.public_id, type: 'authenticated', bytes: buffer.length }); } });
    const User = require('../src/models/User');
    const Country = require('../src/models/Country');
    const University = require('../src/models/University');
    const Program = require('../src/models/Program');
    const Application = require('../src/models/Application');
    const Invoice = require('../src/models/Invoice');
    const Notification = require('../src/models/Notification');
    const student = await User.create({ name: 'Student', email: 'student@example.test' });
    const other = await User.create({ name: 'Other', email: 'other@example.test' });
    const advisor = await User.create({ name: 'Mona', email: 'mona@example.test', role: 'employee', permissions: ['applications'] });
    const reviewer = await User.create({ name: 'Rami', email: 'rami@example.test', role: 'employee', permissions: ['student-documents'] });
    const turkey = await Country.create({ name: 'Turkey', code: 'TR' });
    const istanbul = await University.create({ name: 'Istanbul University', city: 'Istanbul', country: turkey._id });
    const ankara = await University.create({ name: 'Ankara University', city: 'Ankara', country: turkey._id });
    const medicine = await Program.create({ title: 'Medicine', university: istanbul._id, degreeLevel: 'bachelor', fieldOfStudy: 'Health', language: 'English', duration: '6 years', intake: 'Fall 2026', careerOpportunities: ['طبيب عام', 'باحث'] });
    await Program.create({ title: 'medicine', university: ankara._id, degreeLevel: 'bachelor', fieldOfStudy: 'Health', tuition: 9000 });
    await Program.create({ title: 'Pharmacy', university: ankara._id, degreeLevel: 'bachelor', fieldOfStudy: 'Health' });
    await Program.create({ title: 'Law', university: ankara._id, degreeLevel: 'bachelor', fieldOfStudy: 'Law' });
    const application = await Application.create({ student: student._id, program: medicine._id, university: istanbul._id, detailedStatus: 'under-review', status: 'under-review', assignedAdvisor: advisor._id, visaCase: { status: 'preparing-documents' }, requiredDocumentTypes: [] });
    await Invoice.create({ student: student._id, application: application._id, invoiceNumber: 'INV-1', description: 'رسوم', amount: 100, dueDate: new Date(Date.now() - 86400000), status: 'unpaid' });

    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const base = `http://127.0.0.1:${server.address().port}/api`;
    const auth = user => ({ Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` });
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(base + endpoint, { method, headers: { 'Content-Type': 'application/json', ...(user ? auth(user) : {}) }, body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }
    let uploadAttempt = 0;
    async function upload(user, fields, expected = 201) {
      const form = new FormData();
      for (const [key, value] of Object.entries(fields)) form.append(key, value);
      form.append('file', new Blob([`%PDF-1.4\nversion ${++uploadAttempt}\n%%EOF`], { type: 'application/pdf' }), `${fields.type || 'file'}.pdf`);
      const response = await fetch(base + '/students/documents', { method: 'POST', headers: auth(user), body: form });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }

    // PRD 21: careers, the same program elsewhere, related programs in the field.
    const programView = await call('GET', `/programs/${medicine._id}`, null);
    assert.deepEqual(programView.careerOpportunities, ['طبيب عام', 'باحث']);
    assert.deepEqual(programView.offeredAt.map(p => p.university.name), ['Ankara University']);
    assert.deepEqual(programView.relatedPrograms.map(p => p.title), ['Pharmacy']);

    // PRD 15/16: the card summarises everything the list and header need.
    const [mine] = await call('GET', '/students/applications', student);
    assert.equal(mine.assignedAdvisor, undefined);
    assert.deepEqual({ ...mine.card, lastUpdate: undefined, applicationStatus: undefined, nextAction: undefined, applicationId: undefined }, {
      university: 'Istanbul University', program: 'Medicine', degreeLevel: 'bachelor', language: 'English', duration: '6 years',
      country: 'Turkey', city: 'Istanbul', campus: 'Istanbul', intake: 'Fall 2026',
      admissionStatus: { status: 'waiting', labelAr: 'بانتظار الفريق أو الجامعة', labelEn: 'Waiting on the team or university', tone: 'info' },
      documentsStatus: { status: 'completed', labelAr: 'مكتمل', labelEn: 'Completed', tone: 'success' },
      paymentStatus: { status: 'overdue', labelAr: 'متأخر', labelEn: 'Overdue', tone: 'danger' },
      visaStatus: { status: 'preparing-documents', labelAr: 'تجهيز المستندات', labelEn: 'Preparing documents' },
      consultant: 'Mona',
      lastUpdate: undefined, applicationStatus: undefined, nextAction: undefined, applicationId: undefined,
    });
    assert.equal(mine.card.applicationStatus.ar.label, 'قيد المراجعة');
    assert.equal(mine.card.nextAction.destination, 'payments');
    assert.ok(mine.card.lastUpdate);

    // PRD 29: new versions keep history; translations link to their original.
    const v1 = await upload(student, { type: 'birth-certificate' });
    await upload(other, { replaces: v1._id }, 404);
    await upload(student, { replaces: 'nope' }, 400);
    await upload(student, { replaces: v1._id, translationOf: v1._id }, 400);
    const v2 = await upload(student, { replaces: v1._id });
    assert.equal(v2.type, 'birth-certificate');
    await upload(student, { replaces: v1._id }, 409);
    const uploadsBefore = uploads;
    await upload(student, { translationOf: new mongoose.Types.ObjectId().toString() }, 404);
    assert.equal(uploads, uploadsBefore, 'nothing is stored when the link is invalid');

    const [latest] = await call('GET', '/students/documents', student);
    assert.equal(latest._id, v2._id);
    assert.equal(latest.isLatest, true);
    assert.deepEqual(latest.versions.map(v => v._id), [v1._id]);
    assert.deepEqual(latest.translation, { status: 'not-required', documentId: null });

    // The reviewer asks for a translation; the student's translation shows up on the original.
    const listed = await call('GET', '/admin/student-documents', reviewer);
    const reviewTarget = listed.find(d => d._id === v2._id);
    await call('PATCH', `/admin/student-documents/${v2._id}`, reviewer, { detailedStatus: 'needs-translation', reviewNote: 'نحتاج ترجمة معتمدة للإنجليزية', version: reviewTarget.__v });
    let docs = await call('GET', '/students/documents', student);
    let original = docs.find(d => d._id === v2._id);
    assert.equal(original.translation.status, 'required');
    assert.deepEqual(original.reviewedBy, { name: 'Rami' });
    const translated = await upload(student, { translationOf: v2._id });
    assert.equal(translated.type, 'translation');
    docs = await call('GET', '/students/documents', student);
    original = docs.find(d => d._id === v2._id);
    assert.equal(original.translation.status, 'uploaded');
    assert.equal(original.translation.documentId, translated._id);
    assert.equal(docs.find(d => d._id === v1._id).isLatest, false);

    // PRD 31: a document request notifies the student with the reason; so do review decisions.
    const fresh = await Application.findById(application._id).lean();
    const requested = await call('POST', `/applications/${application._id}/document-requests`, advisor, { type: 'recommendation-letter', note: 'الجامعة تطلب خطاب توصية من أستاذك', version: fresh.__v }, 201);
    let notice = await Notification.findOne({ user: student._id, title: 'مطلوب منك: خطاب توصية' }).lean();
    assert.match(notice.message, /سبب الطلب: الجامعة تطلب خطاب توصية من أستاذك/);
    assert.equal(notice.type, 'warning');
    const request = requested.documentRequests.at(-1);
    await call('PATCH', `/applications/${application._id}/document-requests/${request._id}`, advisor, { decision: 'cancelled', note: 'تم الاكتفاء بالمستندات الحالية', version: requested.__v });
    notice = await Notification.findOne({ user: student._id, title: 'أُلغي طلب خطاب توصية' }).lean();
    assert.ok(notice);
    await call('POST', `/applications/${application._id}/document-requests`, advisor, { type: 'spaceship-license', note: 'x', version: requested.__v + 1 }, 400);
  } finally {
    if (originalUpload) require('../src/config/cloudinary').cloudinary.uploader.upload_stream = originalUpload;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
