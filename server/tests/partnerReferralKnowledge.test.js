const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
test('partner accepted counts use live owned students and knowledge links are usable and role-scoped', async () => {
  process.env.JWT_SECRET = 'partner-referral-knowledge';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Student = require('../src/models/AgentStudent');
    const Event = require('../src/models/ReferralEvent');
    const Knowledge = require('../src/models/KnowledgeBaseItem');
    const agent = await User.create({ name: 'Partner', email: 'partner@test.example', role: 'partner' });
    const other = await User.create({ name: 'Other', email: 'other@test.example', role: 'partner' });
    const admin = await User.create({ name: 'Admin', email: 'admin@test.example', role: 'admin' });
    const own = await Student.create({ agent: agent._id, name: 'Accepted', email: 'student@test.example', phone: '123', applicationStatus: 'final-accepted' });
    await Student.create({ agent: other._id, name: 'Other student', email: 'other-student@test.example', phone: '123', applicationStatus: 'final-accepted' });
    await Event.insertMany([1, 2, 3].map(() => ({ agent: agent._id, type: 'accepted' })));
    await Knowledge.create({ title: 'Guide', body: 'Read', targetRole: 'partner', videoUrl: '', fileUrl: 'www.example.test/guide.pdf' });
    await Knowledge.create({ title: 'Student only', body: 'Student guide', targetRole: 'student' });
    await Knowledge.create({ title: 'Draft', body: 'Unpublished', published: false });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(method, endpoint, user, body, expected = 200) {
      const res = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined });
      const data = await res.json(); assert.equal(res.status, expected, JSON.stringify(data)); return data;
    }
    assert.equal((await call('GET', '/partners/referral', agent)).summary.acceptedStudents, 1);
    own.applicationStatus = 'rejected'; await own.save();
    assert.equal((await call('GET', '/partners/referral', agent)).summary.acceptedStudents, 0);
    const items = await call('GET', '/partners/knowledge-base', agent);
    assert.equal(items.length, 1); assert.equal(items[0].fileUrl, 'https://www.example.test/guide.pdf');
    const saved = await call('POST', '/admin/knowledge-base', admin, { title: 'New', body: 'Guide', fileUrl: 'example.test/new.pdf' }, 201);
    assert.equal(saved.fileUrl, 'https://example.test/new.pdf');
    await call('POST', '/admin/knowledge-base', admin, { title: 'Invalid', body: 'Guide', fileUrl: 'javascript:alert(1)' }, 400);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
