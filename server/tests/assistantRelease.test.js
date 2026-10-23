const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(process.env.STUDY_BIRDS_TEST_TOOLS
  ? path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core')
  : 'mongodb-memory-server-core');

test('assistant: provider failure, persistence, ownership and daily quota', async () => {
  process.env.JWT_SECRET = 'isolated-assistant-test';
  const originalFetch = global.fetch;
  let mongo, server, calls = 0, fail = false;
  try {
    mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
    await mongoose.connect(mongo.getUri());
    const app = require('../src/app');
    const User = require('../src/models/User');
    await Promise.all(Object.values(mongoose.models).map(model => model.init()));
    const [a, b] = await User.create([
      { name: 'A', email: 'a@example.test' },
      { name: 'B', email: 'b@example.test' },
    ]);
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const origin = `http://127.0.0.1:${server.address().port}/api/assistant`;
    global.fetch = async (url, init) => {
      if (String(url) === 'https://provider.example.test/v1/chat/completions') {
        calls++;
        assert.equal(init.headers.Authorization, 'Bearer test-only');
        const payload = JSON.parse(init.body);
        assert.equal(payload.model, 'test-model');
        if (fail) return new Response('{}', { status: 500 });
        return new Response(JSON.stringify({ choices: [{ message: { content: '{"id":"documents"}' } }], usage: { prompt_tokens: 10, completion_tokens: 5 } }));
      }
      return originalFetch(url, init);
    };
    const call = async (route, user, body, status = 200) => {
      const r = await fetch(origin + route, { method: body ? 'POST' : 'GET', headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${token(user)}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
      const data = await r.json();
      assert.equal(r.status, status, JSON.stringify(data));
      return data;
    };
    await call('/threads', null, null, 401);
    await call('/message', b, {message:'x'.repeat(2001)}, 400);
    delete process.env.AI_API_KEY;
    await call('/message', a, { message: 'How do I upload documents and apply?' }, 503);
    assert.equal(calls, 0);
    Object.assign(process.env, { AI_API_KEY: 'test-only', AI_BASE_URL: 'https://provider.example.test/v1/', AI_MODEL: 'test-model', AI_DAILY_LIMIT: '2' });
    const answer = await call('/message', a, { message: 'How do I upload documents and apply?' });
    assert.equal(answer.messages.length, 2);
    assert.match(answer.messages.at(-1).content, /Open your documents/);
    if(process.env.ASSISTANT_CONTRACT_OUTPUT) require('node:fs').writeFileSync(process.env.ASSISTANT_CONTRACT_OUTPUT, JSON.stringify(answer));
    assert.equal((await call('/threads', a)).length, 1);
    assert.equal((await call('/threads', b)).length, 0);
    await call(`/threads/${answer.threadId}`, b, null, 404);
    await call('/message', b, { threadId: answer.threadId, message: 'Steal' }, 404);
    fail = true;
    await call('/message', a, { threadId: answer.threadId, message: 'How do I upload documents and apply?' }, 502);
    assert.equal((await call(`/threads/${answer.threadId}`, a)).messages.length, 2);
    fail = false;
    await call('/message', a, { threadId: answer.threadId, message: 'How do I upload documents and apply?' }, 429);
    assert.equal(calls, 2);
    const records = await mongoose.model('AssistantGeneration').find().lean();
    assert.deepEqual(records.map(r => r.status).sort(), ['complete', 'failed']);
    assert.equal(records.find(r => r.status === 'complete').inputTokens, 10);
  } finally {
    global.fetch = originalFetch;
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  }
});
