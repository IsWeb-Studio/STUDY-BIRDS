const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('referrals qualify on a real first application, reward the referrer, and wallet credit redeems against an invoice', async () => {
  process.env.JWT_SECRET = 'student-wallet-isolated-test';
  process.env.STUDENT_REFERRAL_REWARD_AMOUNT = '20';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ ip: '127.0.0.1' }] });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const University = require('../src/models/University');
    const Program = require('../src/models/Program');
    const Document = require('../src/models/Document');
    const Invoice = require('../src/models/Invoice');
    const StudentReferral = require('../src/models/StudentReferral');
    const financeStaff = require('../src/models/User');
    const university = await University.create({ name: 'Test University', country: new mongoose.Types.ObjectId(), city: 'City' });
    const program = await Program.create({ title: 'Computer Science', university: university._id, degreeLevel: 'bachelor', fieldOfStudy: 'Computer Science', requiredDocumentTypes: [] });
    const finance = await financeStaff.create({ name: 'Finance', email: 'finance@example.test', role: 'employee', permissions: ['student-financials'] });
    const outsider = await financeStaff.create({ name: 'Outsider', email: 'outsider@example.test', role: 'employee', permissions: ['applications'] });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${token(user)}` } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }

    // Referrer registers and gets a code.
    const referrerSignup = await call('POST', '/auth/register', null, { name: 'Referrer', email: 'referrer@example.test', password: 'Sparrow!Secure2026' }, 201);
    const referrer = { _id: referrerSignup.user._id };
    const wallet0 = await call('GET', '/students/wallet', referrer);
    assert.ok(wallet0.referralCode);
    assert.equal(wallet0.balance, 0);

    // A second call reuses the same code rather than generating a new one.
    assert.equal((await call('GET', '/students/wallet', referrer)).referralCode, wallet0.referralCode);

    // Someone registers with that code; no reward yet — they haven't applied.
    const referredSignup = await call('POST', '/auth/register', null, { name: 'Referred', email: 'referred@example.test', password: 'Sparrow!Secure2026', referralCode: wallet0.referralCode }, 201);
    const referred = { _id: referredSignup.user._id };
    assert.equal((await call('GET', '/students/wallet', referrer)).balance, 0);
    const referralRow = await StudentReferral.findOne({ referredUser: referred._id }).lean();
    assert.equal(referralRow.status, 'pending');

    // An invalid/self-referral code is silently ignored, not an error.
    await call('POST', '/auth/register', null, { name: 'SelfRef', email: 'selfref@example.test', password: 'Sparrow!Secure2026', referralCode: 'DOES-NOT-EXIST' }, 201);

    // The referred student uploads a document and submits their first application — this is the real milestone.
    const document = await Document.create({ student: referred._id, type: 'passport', filePath: '/x', fileName: 'p.pdf' });
    await call('POST', '/applications', referred, { programId: String(program._id), documentIds: [String(document._id)] }, 201);

    const afterFirstApp = await call('GET', '/students/wallet', referrer);
    assert.equal(afterFirstApp.balance, 20);
    assert.equal(afterFirstApp.referrals.length, 1);
    assert.equal(afterFirstApp.referrals[0].status, 'qualified');
    assert.equal(afterFirstApp.transactions[0].kind, 'referral-reward');

    // A second application from the same student never double-rewards.
    const program2 = await Program.create({ title: 'Business', university: university._id, degreeLevel: 'bachelor', fieldOfStudy: 'Business', requiredDocumentTypes: [] });
    await call('POST', '/applications', referred, { programId: String(program2._id), documentIds: [] }, 201);
    assert.equal((await call('GET', '/students/wallet', referrer)).balance, 20);

    // Redemption against an unpaid invoice larger than the wallet balance.
    const invoiceA = await Invoice.create({ student: referrer._id, invoiceNumber: 'INV-1', description: 'Tuition deposit', amount: 100 });
    await call('POST', '/students/wallet/redeem', referred, { invoiceId: invoiceA._id, amount: 5 }, 404); // not their invoice
    for (const invalid of [{ invoiceId: invoiceA._id, amount: 0 }, { invoiceId: invoiceA._id, amount: 1000 }, { invoiceId: 'bad', amount: 5 }]) {
      await call('POST', '/students/wallet/redeem', referrer, invalid, 400);
    }
    const partial = await call('POST', '/students/wallet/redeem', referrer, { invoiceId: invoiceA._id, amount: 12 });
    assert.equal(partial.invoice.status, 'unpaid');
    assert.equal(partial.invoice.walletCreditApplied, 12);
    assert.equal(partial.balance, 8);
    // A redemption within what's still owed but exceeding the wallet balance is rejected.
    await call('POST', '/students/wallet/redeem', referrer, { invoiceId: invoiceA._id, amount: 50 }, 409);
    assert.equal((await call('GET', '/students/wallet', referrer)).balance, 8);

    // Redeeming the entire remaining balance against an exactly-matching invoice settles it.
    const invoiceB = await Invoice.create({ student: referrer._id, invoiceNumber: 'INV-2', description: 'Housing fee', amount: 8 });
    const full = await call('POST', '/students/wallet/redeem', referrer, { invoiceId: invoiceB._id, amount: 8 });
    assert.equal(full.invoice.status, 'paid');
    assert.equal(full.balance, 0);
    // A paid invoice no longer accepts credit.
    await call('POST', '/students/wallet/redeem', referrer, { invoiceId: invoiceB._id, amount: 1 }, 409);

    // Staff manual adjustments require the student-financials section, not just any employee.
    await call('GET', '/admin/student-financials/wallet-entries', outsider, null, 403);
    await call('POST', '/admin/student-financials/wallet-entries', outsider, { studentId: referrer._id, direction: 'credit', amount: 5, notes: 'x' }, 403);
    for (const invalid of [{ direction: 'sideways' }, { amount: -1 }, { notes: '' }]) {
      await call('POST', '/admin/student-financials/wallet-entries', finance, { studentId: referrer._id, direction: 'credit', amount: 5, notes: 'test', ...invalid }, 400);
    }
    // Can't debit a student into a negative balance.
    await call('POST', '/admin/student-financials/wallet-entries', finance, { studentId: referrer._id, direction: 'debit', amount: 100, notes: 'oops' }, 409);
    await call('POST', '/admin/student-financials/wallet-entries', finance, { studentId: referrer._id, direction: 'credit', amount: 8, notes: 'مكافأة يدوية' }, 201);
    const entries = await call('GET', '/admin/student-financials/wallet-entries', finance, null);
    assert.ok(entries.some(e => e.kind === 'adjustment' && e.student._id === String(referrer._id)));
    assert.equal((await call('GET', '/students/wallet', referrer)).balance, 8);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
