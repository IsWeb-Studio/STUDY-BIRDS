const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('staff can assign an airport driver and a travel alert; students see only their own', async () => {
  process.env.JWT_SECRET = 'arrival-pickup-isolated-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const ArrivalServiceRequest = require('../src/models/ArrivalServiceRequest');
    const student = await User.create({ name: 'Student', email: 'student@example.test' });
    const other = await User.create({ name: 'Other', email: 'other@example.test' });
    const arrivalsOfficer = await User.create({ name: 'Arrivals Officer', email: 'arrivals@example.test', role: 'employee', permissions: ['student-arrivals'] });
    const admissions = await User.create({ name: 'Admissions', email: 'admissions@example.test', role: 'employee', permissions: ['applications'] });
    const request = await ArrivalServiceRequest.create({ student: student._id, flightNumber: 'TK123', airport: 'IST', services: { airportPickup: true } });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }
    const route = `/admin/student-arrival-requests/${request._id}`;

    // Only staff with 'student-arrivals' can update; a fresh request starts unassigned.
    await call('PATCH', route, null, { pickup: { status: 'assigned' } }, 401);
    await call('PATCH', route, student, { pickup: { status: 'assigned' } }, 403);
    await call('PATCH', route, admissions, { pickup: { status: 'assigned' } }, 403);
    await call('PATCH', route, arrivalsOfficer, { pickup: { status: 'invented-status' } }, 400);

    const assigned = await call('PATCH', route, arrivalsOfficer, {
      pickup: { status: 'assigned', driverName: 'Ahmed', driverPhone: '+905551234567' },
      travelAlert: 'الطقس ماطر، أحضر مظلة عند الوصول',
    });
    assert.equal(assigned.pickup.status, 'assigned');
    assert.equal(assigned.pickup.driverName, 'Ahmed');
    assert.equal(assigned.travelAlert, 'الطقس ماطر، أحضر مظلة عند الوصول');
    assert.equal(assigned.pickup.confirmedAt, undefined);

    const arrived = await call('PATCH', route, arrivalsOfficer, { pickup: { status: 'arrived' } });
    assert.equal(arrived.pickup.status, 'arrived');
    assert.ok(arrived.pickup.confirmedAt);
    // Driver details already set are preserved when only the status changes.
    assert.equal(arrived.pickup.driverName, 'Ahmed');

    // The student reads their own request with the pickup and alert visible.
    const mine = await call('GET', '/students/arrival-services', student);
    assert.equal(mine[0].pickup.status, 'arrived');
    assert.equal(mine[0].travelAlert, 'الطقس ماطر، أحضر مظلة عند الوصول');

    // A different student has no request of their own and isn't affected.
    const othersRequest = await call('GET', '/students/arrival-services', other);
    assert.deepEqual(othersRequest, []);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
