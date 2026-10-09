const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const { validateInput, requestSafety, safeResponses, escapeSearch } = require('../src/middleware/requestSafety');
const { errorHandler } = require('../src/middleware/errorMiddleware');
const { publicMessage } = require('../src/utils/publicError');
const { checkFile } = require('../src/utils/fileSafety');
const upload = require('../src/middleware/uploadMiddleware');

test('rejects nested database operators and prototype pollution keys', () => {
  for (const payload of [
    { email: { $ne: null } }, { filter: [{ $where: 'while(true){}' }] },
    JSON.parse('{"__proto__":{"admin":true}}'), { 'profile.role': 'admin' },
    { constructor: { prototype: { polluted: true } } },
  ]) assert.throws(() => validateInput(payload), { statusCode: 400 });
  assert.equal({}.polluted, undefined);
});
test('rejects malformed queries, active markup and oversized/deep payloads', () => {
  for (const payload of [{ q: { value: 'hi' } }, { q: 'x'.repeat(501) }]) {
    assert.throws(() => validateInput(payload, { query: true }), { statusCode: 400 });
  }
  for (const text of ['<script>alert(1)</script>', '<img src=x onerror=alert(1)>', 'javascript:alert(1)', '<svg/onload=alert(1)>']) {
    assert.throws(() => validateInput({ message: text }), { statusCode: 400 });
  }
  let deep = {}; for (let i = 0; i < 20; ++i) deep = { child: deep };
  assert.throws(() => validateInput(deep), { statusCode: 400 });
  assert.throws(() => validateInput({ message: 'x'.repeat(65537) }), { statusCode: 400 });
});
test('preserves Arabic, apostrophes, ordinary punctuation, passwords and safe editor HTML', () => {
  const body = { name: "عُبود O'Connor", message: '2 < 3، جامعة إسطنبول',
    content: '<p>أهلًا <strong>بالطالب</strong></p>', password: 'A<script>9$!'
  };
  const before = JSON.stringify(body);
  validateInput(body);
  assert.equal(JSON.stringify(body), before);
  validateInput({ country: ['TR', 'GE'], keyword: 'طب' }, { query: true });
});
test('search treats regex metacharacters as literal text', () => {
  for (const query of ['(a+)+$', '.*', '[', 'طب', 'a\\b']) {
    const regex = new RegExp(escapeSearch(query), 'i');
    assert.equal(regex.test(query), true);
    if (query !== 'طب') assert.equal(regex.test('unrelated'), false);
  }
});
test('hides stacks, internal errors and provider messages, preserves useful auth errors', () => {
  assert.equal(publicMessage(401, 'Invalid credentials'), 'البريد الإلكتروني أو كلمة المرور غير صحيحة.');
  for (const raw of ['MongoServerError: password=secret', '<html>502 gateway</html>', 'تفاصيل MongoDB secret', 'استجابة 500']) {
    assert.doesNotMatch(publicMessage(500, raw), /secret|Mongo|500|502|html/);
    assert.doesNotMatch(publicMessage(400, raw), /secret|Mongo|500|502|html/);
  }
  assert.equal(publicMessage(400, 'رمز غير صحيح أو منتهي الصلاحية'), 'رمز غير صحيح أو منتهي الصلاحية');
});
test('rejects spoofed files, extensions and empty or oversized uploads', () => {
  for (const file of [
    { originalname: 'photo.png', mimetype: 'image/png', buffer: Buffer.from('<script>alert(1)</script>') },
    { originalname: 'photo.exe', mimetype: 'image/png', buffer: Buffer.from('89504e470d0a1a0a', 'hex') },
    { originalname: 'a.txt', mimetype: 'text/plain', buffer: Buffer.from('<svg onload=alert(1)>') },
    { originalname: 'a.pdf', mimetype: 'application/pdf', buffer: Buffer.alloc(0) },
  ]) assert.throws(() => checkFile(file), { statusCode: 415 });
  assert.throws(() => checkFile({ originalname: 'a.txt', mimetype: 'text/plain', buffer: Buffer.alloc(5 * 1024 * 1024 + 1, 65) }), { statusCode: 413 });
});
test('accepts signatures for supported image and document types', () => {
  for (const file of [
    { originalname: 'a.png', mimetype: 'image/png', buffer: Buffer.from('89504e470d0a1a0a', 'hex') },
    { originalname: 'a.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('ffd8ff', 'hex') },
    { originalname: 'a.pdf', mimetype: 'application/pdf', buffer: Buffer.from('%PDF-1.7\n') },
    { originalname: 'a.txt', mimetype: 'text/plain', buffer: Buffer.from('مستند الطالب') },
    { originalname: 'a.docx', mimetype: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', buffer: Buffer.from('504b0304', 'hex') },
  ]) assert.doesNotThrow(() => checkFile(file));
});

test('HTTP boundary handles JSON, query injection, direct errors and multipart fields safely', async () => {
  const app = express();
  app.use(safeResponses);
  app.use(express.json({ limit: '100kb' }));
  app.use(requestSafety);
  app.post('/echo', (req, res) => res.json(req.body));
  app.get('/echo', (req, res) => res.json(req.query));
  app.get('/direct', (req, res) => res.status(503).json({ message: 'SMTP password=secret', stack: 'internal' }));
  app.get('/duplicate', (req, res, next) => next(Object.assign(new Error('E11000 secret'), { code: 11000, keyPattern: { email: 1 } })));
  app.get('/cast', (req, res, next) => next(Object.assign(new Error('CastError secret'), { name: 'CastError' })));
  app.post('/upload', upload.single('file'), (req, res) => res.json({ uploaded: true }));
  app.use(errorHandler);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const request = (body) => fetch(`${base}/echo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
    assert.equal((await request('{"name":"عبود"}')).status, 200);
    for (const body of ['{', '{"email":{"$ne":null}}', '{"__proto__":{"admin":true}}']) {
      const response = await request(body); assert.equal(response.status, 400);
      const data = await response.json(); assert.equal(data.stack, undefined);
    }
    assert.equal((await request(JSON.stringify({ text: 'x'.repeat(110000) }))).status, 413);
    assert.equal((await fetch(`${base}/echo?email[$ne]=x`)).status, 400);
    const direct = await fetch(`${base}/direct`); const body = await direct.json();
    assert.equal(direct.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(body.stack, undefined); assert.doesNotMatch(body.message, /secret|SMTP/);
    assert.equal((await fetch(`${base}/duplicate`)).status, 409);
    assert.equal((await fetch(`${base}/cast`)).status, 400);
    const form = new FormData(); form.append('file', new Blob(['%PDF-1.7\n'], { type: 'application/pdf' }), 'student.pdf');
    assert.equal((await fetch(`${base}/upload`, { method: 'POST', body: form })).status, 200);
    const attack = new FormData(); attack.append('email[$ne]', 'anything');
    attack.append('file', new Blob(['%PDF-1.7\n'], { type: 'application/pdf' }), 'student.pdf');
    assert.equal((await fetch(`${base}/upload`, { method: 'POST', body: attack })).status, 400);
    const fake = new FormData(); fake.append('file', new Blob(['<html>bad</html>'], { type: 'image/png' }), 'image.png');
    assert.equal((await fetch(`${base}/upload`, { method: 'POST', body: fake })).status, 415);
  } finally { await new Promise((resolve) => server.close(resolve)); }
});
