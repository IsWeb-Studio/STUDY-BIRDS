// Provider credentials stay on the server; only normalized replies reach clients.
function configuration(env = process.env) {
  const provider = env.AI_PROVIDER || (env.GEMINI_API_KEY ? 'gemini' : env.ANTHROPIC_API_KEY ? 'anthropic' : 'openai');
  if (provider === 'gemini') {
    const model = env.GEMINI_MODEL || 'gemini-3.5-flash-lite';
    if (!/^[a-zA-Z0-9._-]+$/.test(model)) return null;
    return { provider, key: env.GEMINI_API_KEY, model,
      endpoint: `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` };
  }
  if (provider === 'anthropic') {
    return { provider, key: env.ANTHROPIC_API_KEY,
      model: env.ANTHROPIC_MODEL || 'claude-haiku-5-5',
      endpoint: 'https://api.anthropic.com/v1/messages' };
  }
  if (provider !== 'openai') return null;
  try {
    const endpoint = new URL('chat/completions', String(env.AI_BASE_URL || '').replace(/\/?$/, '/'));
    if (endpoint.protocol !== 'https:') return null;
    return { provider, key: env.AI_API_KEY, model: env.AI_MODEL, endpoint: endpoint.href };
  } catch { return null; }
}

function ready() {
  const config = configuration();
  return Boolean(config?.key?.trim() && config?.model?.trim());
}

async function generateReply(messages, { config = configuration(), fetchImpl = fetch } = {}) {
  if (!config?.key || !config?.model) throw new Error('Assistant is not configured');
  const anthropic = config.provider === 'anthropic';
  const gemini = config.provider === 'gemini';
  const payload = gemini ? {
    systemInstruction: { parts: [{ text: messages.filter(m => m.role === 'system').map(m => m.content).join('\n\n') }] },
    contents: messages.filter(m => m.role === 'user' || m.role === 'assistant').map(m => ({
      role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }],
    })),
    generationConfig: { maxOutputTokens: 2048 },
  } : anthropic ? {
    model: config.model,
    max_tokens: 800,
    system: messages.filter(m => m.role === 'system').map(m => m.content).join('\n\n'),
    messages: messages.filter(m => m.role === 'user' || m.role === 'assistant'),
  } : { model: config.model, max_completion_tokens: 800, messages };
  const headers = gemini ? { 'x-goog-api-key': config.key, 'Content-Type': 'application/json' } : anthropic ? {
    'x-api-key': config.key,
    'anthropic-version': '2023-06-01',
    'Content-Type': 'application/json',
  } : { Authorization: `Bearer ${config.key}`, 'Content-Type': 'application/json' };
  const response = await fetchImpl(config.endpoint, {
    method: 'POST', headers, signal: AbortSignal.timeout(30000),
    body: JSON.stringify(payload),
  });
  // Never include provider bodies or credentials in application errors.
  if (!response.ok) throw new Error('Assistant provider request failed');
  const data = await response.json();
  const text = gemini
    ? (Array.isArray(data.candidates?.[0]?.content?.parts) ? data.candidates[0].content.parts : [])
        .filter(part => !part.thought && typeof part.text === 'string').map(part => part.text).join('\n')
    : anthropic
    ? (Array.isArray(data.content) ? data.content : [])
        .filter(block => block.type === 'text' && typeof block.text === 'string')
        .map(block => block.text).join('\n')
    : data.choices?.[0]?.message?.content;
  if (typeof text !== 'string' || !text.trim()) throw new Error('Assistant returned no text');
  return {
    text: text.trim().slice(0, 12000), model: (gemini ? data.modelVersion : data.model) || config.model,
    inputTokens: (gemini ? data.usageMetadata?.promptTokenCount : anthropic ? data.usage?.input_tokens : data.usage?.prompt_tokens) || 0,
    outputTokens: (gemini ? (data.usageMetadata?.candidatesTokenCount || 0) + (data.usageMetadata?.thoughtsTokenCount || 0) : anthropic ? data.usage?.output_tokens : data.usage?.completion_tokens) || 0,
  };
}

module.exports = { configuration, ready, generateReply };
