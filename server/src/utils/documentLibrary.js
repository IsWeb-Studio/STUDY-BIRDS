const { createHash } = require('node:crypto');
const mongoose = require('mongoose');
const Document = require('../models/Document');
const { withLease } = require('./leaseLock');
const { uploadPrivateDocument } = require('./privateDocumentStorage');

const fail = (status, message) => Object.assign(new Error(message), { statusCode: status });
const hashFile = buffer => createHash('sha256').update(buffer).digest('hex');
const contentKey = ({ student, type, fileHash, translationOf }) =>
  hashFile(Buffer.from(JSON.stringify([String(student), type, fileHash, String(translationOf || '')])));

// Reuse the existing shared lease architecture. Hashes are computed by the
// server; client hashes are only lookup hints and never authorize access.
async function saveLibraryDocument({ student, file, type, previous, translationOf, passportReview }) {
  const fileHash = hashFile(file.buffer);
  const query = { student, type, fileHash, size: file.buffer.length, translationOf: translationOf || null };
  const existing = await Document.findOne(query).sort({ createdAt: 1 });
  if (existing) {
    if (previous?.supersededBy && String(previous.supersededBy) !== String(existing._id)) {
      throw fail(409, 'A newer version of this document already exists');
    }
    if (existing.archivedAt && !existing.supersededBy) {
      await Document.updateOne({ _id: existing._id }, { $unset: { archivedAt: 1 } });
      existing.archivedAt = undefined;
    }
    if (previous && String(existing.replaces || '') === String(previous._id)) {
      await Document.updateOne({ _id: previous._id, supersededBy: null }, { supersededBy: existing._id });
    }
    return { document: existing, reused: true };
  }
  const key = contentKey({ student, type, fileHash, translationOf });
  return withLease(`document-upload:${key}`, async () => {
    const completed = await Document.findOne(query).sort({ createdAt: 1 });
    if (completed) return { document: completed, reused: true };
    if (previous?.supersededBy) throw fail(409, 'A newer version of this document already exists');
    const documentId = new mongoose.Types.ObjectId(key.slice(0, 24));
    if (await Document.exists({ _id: documentId })) throw fail(409, 'Document identity conflict. Contact support.');
    const extension = { 'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
      'text/plain': 'txt', 'application/zip': 'zip', 'application/x-zip-compressed': 'zip',
      'application/msword': 'doc', 'application/vnd.ms-excel': 'xls', 'application/vnd.ms-powerpoint': 'ppt',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
    }[file.mimetype];
    // Stable private storage identity recovers a crash between storage and DB.
    const storageKey = hashFile(Buffer.from(JSON.stringify([String(student), fileHash])));
    const storage = await uploadPrivateDocument({ ...file, originalname: `document.${extension || 'bin'}` }, { contentId: storageKey });
    const document = await Document.findOneAndUpdate({ _id: documentId }, { $setOnInsert: {
      student, type, fileHash, uploadStatus: 'uploaded', fileName: file.originalname,
      filePath: `/api/documents/${documentId}/access`, storage, mimeType: file.mimetype,
      size: file.buffer.length, version: (previous?.version || 0) + 1,
      ...(previous ? { replaces: previous._id } : {}),
      ...(translationOf ? { translationOf } : {}),
      ...(passportReview ? { passportReview, expiresAt: new Date(passportReview.reviewed.expiry) } : {}),
    } }, { upsert: true, new: true, runValidators: true });
    if (previous) {
      const linked = await Document.updateOne({ _id: previous._id,
        $or: [{ supersededBy: { $exists: false } }, { supersededBy: document._id }] }, { supersededBy: document._id });
      if (!linked.matchedCount) {
        await Document.updateOne({ _id: document._id }, { $unset: { replaces: 1 }, $set: { archivedAt: new Date() } });
        throw fail(409, 'Another replacement completed first. Refresh your documents.');
      }
    }
    return { document, reused: false };
  }, { ms: 5 * 60 * 1000, waitMs: 3000, renew: true });
}

module.exports = { saveLibraryDocument, hashFile, contentKey };
