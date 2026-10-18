// Run from server/: node scripts/migrateVerificationDocuments.js [--apply]
// Dry-run is the default. --apply moves existing assets to authenticated storage
// and requests CDN invalidation; do not report completion before it succeeds.
require('dotenv').config();
const mongoose = require('mongoose');
const VerificationDocument = require('../src/models/VerificationDocument');
const { legacyAsset } = require('../src/utils/legacyDocumentStorage');
const { migrateVerificationDocument } = require('../src/utils/verificationDocumentMigration');

async function main() {
  if (!process.env.MONGODB_URI || !process.env.CLOUDINARY_CLOUD_NAME) {
    throw new Error('MONGODB_URI and CLOUDINARY_CLOUD_NAME are required');
  }
  const apply = process.argv.includes('--apply');
  const report = { mode: apply ? 'apply' : 'dry-run', candidates: 0, migrated: 0, failed: 0 };
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    for await (const document of VerificationDocument.find({ 'storage.deliveryType': { $ne: 'authenticated' } }).select('+storage').cursor()) {
      report.candidates++;
      try {
        const oldPath = document.filePath;
        const source = legacyAsset(oldPath, process.env.CLOUDINARY_CLOUD_NAME);
        if (!source.publicId.startsWith('study-birds/agent-verification/')) throw new Error('Unexpected asset folder');
        if (!apply) continue;
        const storage = await migrateVerificationDocument(document);
        const result = await VerificationDocument.updateOne({ _id: document._id, filePath: oldPath }, {
          $set: { storage, legacyFilePath: oldPath, filePath: `/api/verification-documents/${document._id}/access` },
        });
        if (!result.matchedCount) throw new Error('Document changed during migration');
        report.migrated++;
      } catch {
        report.failed++;
        // Only an identifier is logged, never a sensitive public URL or credential.
        console.error('Verification migration failed for document', String(document._id));
      }
    }
    console.log(JSON.stringify(report));
    if (report.failed) process.exitCode = 1;
  } finally { await mongoose.disconnect(); }
}
if (require.main === module) main().catch(() => { console.error('Verification migration could not complete'); process.exitCode = 1; });
module.exports = { main };
