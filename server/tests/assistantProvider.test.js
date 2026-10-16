const { test } = require('node:test');
const assert = require('node:assert/strict');
const { configuration, generateReply } = require('../src/utils/assistantProvider');

test('Gemini preserves system guidance, private reference context and conversation roles', async () => {
  const config = configuration({ AI_PROVIDER: 'gemini', GEMINI_API_KEY: 'gemini-test-secret' });
  const reply = await generateReply([
    { role: 'system', content: 'Birds guidance' }, { role: 'system', content: 'Reference data' },
    { role: 'user', content: 'Previous' }, { role: 'assistant', content: 'Previous answer' },
    { role: 'user', content: 'Current question' },
  ], { config, fetchImpl: async (url, options) => {
    assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent');
    assert.ok(!url.includes('secret'));
    assert.equal(options.headers['x-goog-api-key'], 'gemini-test-secret');
    assert.equal(options.headers.Authorization, undefined);
    const body = JSON.parse(options.body);
    assert.equal(body.systemInstruction.parts[0].text, 'Birds guidance\n\nReference data');
    assert.deepEqual(body.contents.map(m => m.role), ['user', 'model', 'user']);
    assert.equal(body.generationConfig.maxOutputTokens, 2048);
    return Response.json({ modelVersion: 'gemini-3.5-flash-lite', candidates: [{ content: { parts: [
      { thought: true, text: 'Internal reasoning' }, { text: 'Student answer' }, { text: 'Follow-up' },
    ] } }], usageMetadata: { promptTokenCount: 20, candidatesTokenCount: 8, thoughtsTokenCount: 4 } });
  } });
  assert.equal(reply.text, 'Student answer\nFollow-up');
  assert.equal(reply.inputTokens, 20); assert.equal(reply.outputTokens, 12);
  assert.equal(configuration({ GEMINI_API_KEY: 'test' }).provider, 'gemini');
  assert.equal(configuration({ AI_PROVIDER: 'gemini', GEMINI_MODEL: '../invalid?key=bad' }), null);
  await assert.rejects(generateReply([], { config, fetchImpl: async () => Response.json({ candidates: [] }) }), /no text/);
  await assert.rejects(generateReply([], { config, fetchImpl: async () => new Response('secret', { status: 403 }) }), /Assistant provider request failed/);
});

test('Claude messages preserve guidance, reference context and conversation history', async () => {
  const config = configuration({ ANTHROPIC_API_KEY: 'test-secret' });
  const reply = await generateReply([
    { role: 'system', content: 'Guidance' }, { role: 'system', content: 'Read-only reference' },
    { role: 'user', content: 'Previous question' }, { role: 'assistant', content: 'Previous answer' },
    { role: 'user', content: 'Current question' },
  ], { config, fetchImpl: async (url, options) => {
    assert.equal(url, 'https://api.anthropic.com/v1/messages');
    assert.equal(options.headers['x-api-key'], 'test-secret');
    assert.equal(options.headers['anthropic-version'], '2023-06-01');
    assert.equal(options.headers.Authorization, undefined);
    const body = JSON.parse(options.body);
    assert.equal(body.system, 'Guidance\n\nRead-only reference');
    assert.deepEqual(body.messages.map(m => m.role), ['user', 'assistant', 'user']);
    assert.equal(body.max_tokens, 800);
    assert.equal(body.max_completion_tokens, undefined);
    return Response.json({ model: config.model, content: [
      { type: 'thinking', thinking: 'internal' }, { type: 'text', text: 'First' }, { type: 'text', text: 'Second' },
    ], usage: { input_tokens: 20, output_tokens: 8 } });
  } });
  assert.equal(reply.text, 'First\nSecond');
  assert.equal(reply.inputTokens, 20);
  assert.equal(reply.outputTokens, 8);
});

test('legacy compatible provider remains available', async () => {
  const config = configuration({ AI_API_KEY: 'legacy', AI_MODEL: 'test-model', AI_BASE_URL: 'https://provider.example.test/v1/' });
  const reply = await generateReply([{ role: 'user', content: 'Hello' }], { config,
    fetchImpl: async (url, options) => {
      assert.equal(url, 'https://provider.example.test/v1/chat/completions');
      assert.equal(options.headers.Authorization, 'Bearer legacy');
      return Response.json({ choices: [{ message: { content: 'Answer' } }], usage: { prompt_tokens: 2, completion_tokens: 1 } });
    } });
  assert.equal(reply.text, 'Answer');
  assert.equal(reply.inputTokens, 2);
});

test('provider errors, missing text and invalid configuration fail without exposing secrets', async () => {
  const config = configuration({ ANTHROPIC_API_KEY: 'test-secret' });
  await assert.rejects(generateReply([], { config, fetchImpl: async () =>
    new Response('sensitive provider details', { status: 400 }) }), /Assistant provider request failed/);
  await assert.rejects(generateReply([], { config, fetchImpl: async () => Response.json({ content: [] }) }), /no text/);
  assert.equal(configuration({ AI_PROVIDER: 'unknown' }), null);
  assert.equal(configuration({ AI_BASE_URL: 'http://unsafe.example.test' }), null);
});
