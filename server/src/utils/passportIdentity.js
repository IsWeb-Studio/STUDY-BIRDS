const StudentProfile = require('../models/StudentProfile');
const Document = require('../models/Document');

// Store the first successfully uploaded OCR claim, not an identity-verification
// decision. A conditional write prevents concurrent uploads from replacing it.
// Reading the profile also recovers a crash after document storage but before
// this snapshot, and supports passports uploaded before this feature existed.
async function ensurePassportIdentity(user) {
  const profile = await StudentProfile.findOne({ user });
  if (profile?.passportIdentity) return;
  const candidates = Document.find({
    student: user, type: 'passport', translationOf: null, archivedAt: null,
    'passportReview.clientReportedMrzChecksPassed': true,
    'passportReview.extracted.number': { $exists: true },
  }).sort({ createdAt: 1, _id: 1 }).lean().cursor();
  let source, review;
  for await (const candidate of candidates) {
    try {
      const fields = candidate.passportReview.extracted;
      review = Document.parsePassportReview(JSON.stringify({
        extracted: fields, reviewed: fields, clientReportedMrzChecksPassed: true,
      }));
      source = candidate;
      break;
    } catch { /* Skip incomplete historical OCR without blocking the profile. */ }
  }
  if (!source) return;
  const fields = review.extracted;
  try {
    await StudentProfile.updateOne({ user }, { $setOnInsert: { user } }, { upsert: true });
  } catch (error) {
    if (error.code !== 11000) throw error;
  }
  await StudentProfile.updateOne({ user, passportIdentity: null }, { $set: {
    passportIdentity: { ...review.extracted, document: source._id, capturedAt: new Date() },
    passportNumber: fields.number, dateOfBirth: new Date(`${fields.birth}T00:00:00Z`),
    englishFullName: fields.name, nationality: fields.nationality,
  } }, { runValidators: true });
}

module.exports = { ensurePassportIdentity };
