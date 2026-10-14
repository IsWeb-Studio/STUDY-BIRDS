// Safe additive migration. Default: dry run. No records, files or request
// references are deleted or merged. Run with --apply only against the intended DB.
require('dotenv').config();
const mongoose = require('mongoose');
const Document = require('../src/models/Document');
const { hashFile } = require('../src/utils/documentLibrary');
const { documentDownloadLink } = require('../src/utils/privateDocumentStorage');

async function readBounded(response) {
  if (!response.ok || !response.body) throw new Error('Download unavailable');
  const parts = []; let size = 0;
  for await (const part of response.body) {
    size += part.length;
    if (size > 5 * 1024 * 1024) { await response.body.cancel().catch(() => {}); throw new Error('File exceeds supported size'); }
    parts.push(Buffer.from(part));
  }
  return Buffer.concat(parts);
}

async function main() {
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI is required');
  await mongoose.connect(process.env.MONGODB_URI);
  const apply = process.argv.includes('--apply');
  const report = { mode: apply ? 'apply' : 'dry-run', candidates: 0, hashed: 0, needsPrivateStorageMigration: 0, failed: 0 };
  for await (const document of Document.find({ fileHash: { $exists: false } }).select('+storage').cursor()) {
    report.candidates++;
    if (!document.storage?.publicId || document.storage.deliveryType !== 'authenticated') {
      report.needsPrivateStorageMigration++; continue;
    }
    if (!apply) continue;
    try {
      const { url } = documentDownloadLink(document.storage);
      const buffer = await readBounded(await fetch(url, { signal: AbortSignal.timeout(30_000) }));
      // Metadata only; storage identity and original application references stay.
      await Document.updateOne({ _id: document._id, fileHash: { $exists: false } },
        { $set: { fileHash: hashFile(buffer), size: buffer.length, uploadStatus: 'uploaded' } });
      report.hashed++;
    } catch { report.failed++; }
  }
  if (apply) await Document.createIndexes(); // Adds indexes; does not drop any.
  console.log(JSON.stringify(report)); // Counts only, never names or signed URLs.
}

main().catch(() => { console.error('Document metadata migration failed'); process.exitCode = 1; })
  .finally(() => mongoose.disconnect());
