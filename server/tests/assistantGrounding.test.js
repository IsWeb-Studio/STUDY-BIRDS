const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('COVEY AI grounds replies in the knowledge base and the asking student\'s own application, never another user\'s', async () => {
  process.env.JWT_SECRET = 'assistant-grounding-isolated-test';
  Object.assign(process.env, { AI_API_KEY: 'test-only', AI_BASE_URL: 'https://provider.example.test/v1/', AI_MODEL: 'test-model' });
  const originalFetch = global.fetch;
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const University = require('../src/models/University');
    const Program = require('../src/models/Program');
    const Application = require('../src/models/Application');
    const KnowledgeBaseItem = require('../src/models/KnowledgeBaseItem');
    const student = await User.create({ name: 'Student', email: 'student@example.test' });
    const parent = await User.create({ name: 'Parent', email: 'parent@example.test', role: 'parent' });
    const university = await University.create({ name: 'Test University', country: new mongoose.Types.ObjectId(), city: 'City' });
    const program = await Program.create({ title: 'Computer Science', university: university._id, degreeLevel: 'bachelor', fieldOfStudy: 'Computer Science' });
    await Application.create({ student: student._id, program: program._id, university: university._id, detailedStatus: 'under-review', requiredDocumentTypes: [] });
    await KnowledgeBaseItem.create({ title: 'Turkish student visa requirements', body: 'You need a passport, an acceptance letter and proof of funds.', published: true, targetRole: 'all' });
    await KnowledgeBaseItem.create({ title: 'Unrelated draft article', body: 'This one should never match.', published: false, targetRole: 'all' });

    let capturedMessages;
    global.fetch = async (url, init) => {
      if (String(url) === 'https://provider.example.test/v1/chat/completions') {
        capturedMessages = JSON.parse(init.body).messages;
        return new Response(JSON.stringify({ choices: [{ message: { content: 'Test answer' } }], usage: { prompt_tokens: 1, completion_tokens: 1 } }));
      }
      return originalFetch(url, init);
    };
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    async function call(user, message) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api/assistant/message`, { method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ userId: user._id }, process.env.JWT_SECRET)}` },
        body: JSON.stringify({ message }) });
      assert.equal(response.status, 200);
      return response.json();
    }

    await call(student, 'What are the visa requirements?');
    const systemMessages = capturedMessages.filter(m => m.role === 'system');
    assert.equal(systemMessages.length, 3, JSON.stringify(systemMessages));
    assert.match(systemMessages[1].content, /Computer Science/);
    assert.match(systemMessages[1].content, /under-review/);
    assert.match(systemMessages[2].content, /Turkish student visa requirements/);
    assert.doesNotMatch(systemMessages[2].content, /Unrelated draft article/);

    // A non-student role never receives another user's (or its own, since it
    // has none) application data injected, even though knowledge base
    // matching still runs for their message.
    await call(parent, 'What are the visa requirements?');
    const parentSystemMessages = capturedMessages.filter(m => m.role === 'system');
    assert.equal(parentSystemMessages.length, 2, JSON.stringify(parentSystemMessages));
    assert.match(parentSystemMessages[1].content, /Turkish student visa requirements/);

    // An unrelated message with no keyword overlap pulls in no knowledge excerpts.
    await call(student, 'zzz qqq xyz');
    assert.equal(capturedMessages.filter(m => m.role === 'system').length, 2);
  } finally {
    global.fetch = originalFetch;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
