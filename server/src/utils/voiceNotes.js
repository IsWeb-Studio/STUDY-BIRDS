const crypto = require('node:crypto');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');
const fail = (message, statusCode = 415) => { throw Object.assign(new Error(message), { statusCode }); };
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_SECONDS = 180;

function boxes(buffer, start = 0, end = buffer.length) {
  const result = [];
  while (start < end) {
    if (end - start < 8 || result.length >= 512) fail('Invalid audio container');
    let size = buffer.readUInt32BE(start), header = 8;
    const type = buffer.toString('ascii', start + 4, start + 8);
    if (size === 1) {
      if (end - start < 16) fail('Invalid audio container');
      const big = buffer.readBigUInt64BE(start + 8);
      if (big > BigInt(MAX_BYTES)) fail('Invalid audio container');
      size = Number(big); header = 16;
    }
    if (size === 0) size = end - start;
    if (size < header || start + size > end) fail('Invalid audio container');
    result.push({ type, start: start + header, end: start + size }); start += size;
  }
  return result;
}
function validateVoice(file) {
  if (!file || !['audio/mp4', 'audio/m4a', 'audio/x-m4a'].includes(file.mimetype) || !/\.m4a$/i.test(file.originalname)) fail('Use an M4A voice recording');
  if (!Buffer.isBuffer(file.buffer) || file.buffer.length < 24) fail('Invalid audio file');
  if (file.buffer.length > MAX_BYTES) fail('Voice recording exceeds 5 MB', 413);
  const top = boxes(file.buffer);
  const ftyp = top.find(b => b.type === 'ftyp'), moov = top.find(b => b.type === 'moov');
  if (!ftyp || ftyp.end - ftyp.start < 8 || !moov || !top.some(b => b.type === 'mdat' && b.end > b.start)) fail('Invalid audio container');
  const tracks = boxes(file.buffer, moov.start, moov.end).filter(b => b.type === 'trak');
  if (!tracks.length || tracks.length > 2) fail('Invalid audio tracks');
  for (const track of tracks) {
    const mdia = boxes(file.buffer, track.start, track.end).find(b => b.type === 'mdia');
    const handler = mdia && boxes(file.buffer, mdia.start, mdia.end).find(b => b.type === 'hdlr');
    if (!handler || handler.end - handler.start < 12 || file.buffer.toString('ascii', handler.start + 8, handler.start + 12) !== 'soun') fail('Only audio recordings are allowed');
  }
}
async function removeVoice(audio) {
  if (!audio?.publicId) return;
  ensureCloudinaryConfigured();
  const result = await cloudinary.uploader.destroy(audio.publicId, { resource_type: 'video', type: 'authenticated', invalidate: true });
  if (!['ok', 'not found'].includes(result.result)) throw new Error('Voice deletion was not confirmed');
}
async function uploadVoice(file, owner) {
  validateVoice(file); ensureCloudinaryConfigured();
  const result = await new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream({ resource_type: 'video', type: 'authenticated',
      public_id: `chat-audio/${owner}/${crypto.randomUUID()}`, format: 'm4a', overwrite: false },
      (error, result) => error ? reject(error) : resolve(result));
    stream.on?.('error', reject); stream.end(file.buffer);
  });
  const audio = { publicId: result.public_id, format: 'm4a', duration: result.duration, resourceType: 'video', deliveryType: 'authenticated' };
  if (!audio.publicId || result.video || !result.audio || !Number.isFinite(audio.duration) || audio.duration < .3 || audio.duration > MAX_SECONDS || result.bytes > MAX_BYTES) {
    await removeVoice(audio); fail('Voice recording must be audio only and between 1 second and 3 minutes', 400);
  }
  return audio;
}
async function readVoice(audio) {
  ensureCloudinaryConfigured();
  const url = cloudinary.url(audio.publicId, { resource_type: 'video', type: 'authenticated', secure: true, sign_url: true, format: 'm4a' });
  const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
  if (!response.ok) fail('Voice recording unavailable', 502);
  const chunks = []; let length = 0;
  for await (const chunk of response.body) {
    length += chunk.length;
    if (length > MAX_BYTES) { await response.body.cancel?.().catch(() => {}); fail('Voice recording too large', 502); }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}
function sendVoice(res, bytes) {
  res.set({ 'Content-Type': 'audio/mp4', 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff', 'Content-Disposition': 'inline; filename="voice.m4a"' }).send(bytes);
}
module.exports = { validateVoice, uploadVoice, readVoice, removeVoice, sendVoice, MAX_BYTES, MAX_SECONDS };
