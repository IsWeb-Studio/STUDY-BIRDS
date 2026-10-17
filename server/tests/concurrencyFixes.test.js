// Regression tests for the two defects confirmed by the 24 Sep 2026 audit
// (PRD_AUDIT_2026-09-24.md): simultaneous wallet redemptions overspending a
// balance, and a capacity-1 accommodation accepting two confirmed bookings.
// The race windows are widened on purpose (slowed reads) so the tests fail
// deterministically without the fix.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryReplSet } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

test('wallet and housing hold under simultaneous requests', async () => {
  process.env.JWT_SECRET = 'concurrency-fix-test';
  const mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ ip: '127.0.0.1' }] });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Invoice = require('../src/models/Invoice');
    const StudentWalletEntry = require('../src/models/StudentWalletEntry');
    const University = require('../src/models/University');
    const AccommodationListing = require('../src/models/AccommodationListing');
    const AccommodationBooking = require('../src/models/AccommodationBooking');
    const WorkerLease = require('../src/models/WorkerLease');
    const student = await User.create({ name: 'Student', email: 'student@example.test' });
    const second = await User.create({ name: 'Second', email: 'second@example.test' });
    const finance = await User.create({ name: 'Finance', email: 'finance@example.test', role: 'employee', permissions: ['student-financials'] });
    const housing = await User.create({ name: 'Housing', email: 'housing@example.test', role: 'employee', permissions: ['housing'] });
    const housing2 = await User.create({ name: 'Housing 2', email: 'housing2@example.test', role: 'employee', permissions: ['housing'] });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const call = async (method, endpoint, user, body) => {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` },
        body: body ? JSON.stringify(body) : undefined });
      return { status: response.status, body: await response.json() };
    };
    const balance = async (userId) => (await StudentWalletEntry.find({ student: userId }).lean())
      .reduce((sum, e) => sum + (e.direction === 'credit' ? e.amount : -e.amount), 0);

    // Slow the balance read so both requests would read 10 before either debits.
    const originalAggregate = StudentWalletEntry.aggregate.bind(StudentWalletEntry);
    StudentWalletEntry.aggregate = function slowAggregate(...args) {
      const query = originalAggregate(...args);
      const exec = query.exec.bind(query);
      query.exec = async () => { await pause(150); return exec(); };
      return query;
    };

    // Audit scenario 1: balance 10, two simultaneous redemptions of 10 on two invoices.
    await StudentWalletEntry.create({ student: student._id, direction: 'credit', kind: 'adjustment', amount: 10, notes: 'seed' });
    const invoiceA = await Invoice.create({ student: student._id, invoiceNumber: 'INV-A', description: 'A', amount: 10 });
    const invoiceB = await Invoice.create({ student: student._id, invoiceNumber: 'INV-B', description: 'B', amount: 10 });
    const results = await Promise.all([
      call('POST', '/students/wallet/redeem', student, { invoiceId: invoiceA._id, amount: 10 }),
      call('POST', '/students/wallet/redeem', student, { invoiceId: invoiceB._id, amount: 10 }),
    ]);
    assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
    assert.equal(await balance(student._id), 0, 'never negative');
    assert.equal(await Invoice.countDocuments({ student: student._id, status: 'paid' }), 1);

    // A staff debit racing a redemption can't overspend either.
    await StudentWalletEntry.create({ student: student._id, direction: 'credit', kind: 'adjustment', amount: 5, notes: 'seed 2' });
    const invoiceC = await Invoice.create({ student: student._id, invoiceNumber: 'INV-C', description: 'C', amount: 5 });
    const mixed = await Promise.all([
      call('POST', '/students/wallet/redeem', student, { invoiceId: invoiceC._id, amount: 5 }),
      call('POST', '/admin/student-financials/wallet-entries', finance, { studentId: student._id, direction: 'debit', amount: 5, notes: 'تصحيح' }),
    ]);
    assert.equal(mixed.filter(r => r.status === 409).length, 1);
    assert.equal(await balance(student._id), 0);
    StudentWalletEntry.aggregate = originalAggregate;

    // Audit scenario 2: capacity-1 listing, two pending requests confirmed at once.
    const university = await University.create({ name: 'Uni', country: new mongoose.Types.ObjectId(), city: 'City' });
    const listing = await AccommodationListing.create({ title: 'Single room', type: 'single', university: university._id, price: 100, capacity: 1 });
    const bookingA = (await call('POST', '/accommodation/bookings', student, { listingId: listing._id })).body;
    const bookingB = (await call('POST', '/accommodation/bookings', second, { listingId: listing._id })).body;
    const originalCount = AccommodationBooking.countDocuments.bind(AccommodationBooking);
    AccommodationBooking.countDocuments = async (...args) => { const n = await originalCount(...args); await pause(150); return n; };
    const confirmations = await Promise.all([
      call('PATCH', `/admin/accommodation-bookings/${bookingA._id}`, housing, { status: 'confirmed', version: bookingA.__v }),
      call('PATCH', `/admin/accommodation-bookings/${bookingB._id}`, housing2, { status: 'confirmed', version: bookingB.__v }),
    ]);
    AccommodationBooking.countDocuments = originalCount;
    assert.deepEqual(confirmations.map(r => r.status).sort(), [200, 409]);
    assert.equal(await AccommodationBooking.countDocuments({ listing: listing._id, status: 'confirmed' }), 1);
    assert.ok(confirmations.find(r => r.status === 409).body.message.length > 0);

    // A full listing takes no new requests; cancelling frees the place again.
    const third = await User.create({ name: 'Third', email: 'third@example.test' });
    assert.equal((await call('POST', '/accommodation/bookings', third, { listingId: listing._id })).status, 409);
    const confirmed = await AccommodationBooking.findOne({ listing: listing._id, status: 'confirmed' }).lean();
    assert.equal((await call('PATCH', `/admin/accommodation-bookings/${confirmed._id}`, housing, { status: 'cancelled', version: confirmed.__v })).status, 200);
    const waiting = await AccommodationBooking.findOne({ listing: listing._id, status: 'pending' }).lean();
    assert.equal((await call('PATCH', `/admin/accommodation-bookings/${waiting._id}`, housing, { status: 'confirmed', version: waiting.__v })).status, 200);

    // One student can't open two requests by double-submitting.
    const listing2 = await AccommodationListing.create({ title: 'Shared room', type: 'shared', university: university._id, price: 50, capacity: 3 });
    const doubled = await Promise.all([
      call('POST', '/accommodation/bookings', third, { listingId: listing2._id }),
      call('POST', '/accommodation/bookings', third, { listingId: listing2._id }),
    ]);
    assert.deepEqual(doubled.map(r => r.status).sort(), [201, 409]);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
