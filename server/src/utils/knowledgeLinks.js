function knowledgeUrl(value) {
  if (value == null || value === '') return '';
  if (typeof value !== 'string') throw new Error('Invalid resource URL');
  let raw = value.trim();
  if (!raw) return '';
  if (/[\s\\]/.test(raw)) throw new Error('Invalid resource URL');
  if (raw.startsWith('//')) raw = `https:${raw}`;
  if (raw.startsWith('/')) return raw;
  if (!raw.includes('://')) {
    if (!/^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}(?::\d+)?(?:\/|\?|#|$)/.test(raw)) throw new Error('Invalid resource URL');
    raw = `https://${raw}`;
  }
  const url = new URL(raw);
  if (!['http:', 'https:'].includes(url.protocol) || !url.hostname || url.username || url.password) throw new Error('Invalid resource URL');
  return url.href;
}
function knowledgeLinkFields(body) {
  const result = {};
  for (const key of ['fileUrl', 'videoUrl']) {
    if (body[key] === undefined) continue;
    try { result[key] = knowledgeUrl(body[key]); }
    catch { throw Object.assign(new Error('Enter a valid HTTP or HTTPS resource link.'), { statusCode: 400 }); }
  }
  return result;
}
function publicKnowledgeItem(item) {
  const result = item.toObject ? item.toObject() : { ...item };
  for (const key of ['fileUrl', 'videoUrl']) {
    try { result[key] = knowledgeUrl(result[key]); } catch { result[key] = ''; }
  }
  return result;
}
module.exports = { knowledgeUrl, knowledgeLinkFields, publicKnowledgeItem };
