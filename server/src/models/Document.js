const mongoose = require("mongoose");

// Client OCR and user edits are separate claims, never trusted identity checks.
const passportFieldsSchema = new mongoose.Schema({
  number: { type: String, maxlength: 9 }, name: { type: String, maxlength: 200 },
  nationality: { type: String, maxlength: 3 }, birth: { type: String, maxlength: 10 },
  expiry: { type: String, maxlength: 10 }, sex: { type: String, maxlength: 1 },
}, { _id: false });

const documentSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
    fileName: {
      type: String,
      required: true,
    },
    filePath: {
      type: String,
      required: true,
    },
    storage: { type: new mongoose.Schema({
      publicId: String, resourceType: String, deliveryType: String, format: String,
    }, { _id: false }), select: false },
    mimeType: String,
    size: Number,
    fileHash: { type: String, match: /^[a-f0-9]{64}$/ },
    uploadStatus: { type: String, enum: ['uploaded'], default: 'uploaded' },
    version: { type: Number, default: 1 },
    archivedAt: Date,
    legacyFilePath: { type: String, select: false },
    status: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },
    // NEW — granular 8-value lifecycle used by the mobile app (Missing,
    // Uploaded, Under Review, Approved, Rejected, Needs Revision, Needs
    // Translation, Expired). `status` above is untouched and kept in sync
    // automatically, so the website's existing document views are
    // unaffected.
    detailedStatus: {
      type: String,
      enum: [
        "missing",
        "uploaded",
        "under-review",
        "approved",
        "rejected",
        "needs-revision",
        "needs-translation",
        "expired",
      ],
      default: "uploaded",
    },
    // Staff review. reviewNote is shown to the student as the reason
    // (mandatory for rejected / needs-revision / needs-translation).
    reviewNote: { type: String, default: "", trim: true, maxlength: 1000 },
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    reviewedAt: Date,
    // Optional validity end (passport, language certificate...). Past it the
    // document is moved to "expired" — see utils/documentExpiry.js.
    expiresAt: Date,
    reviewHistory: [{
      _id: false,
      detailedStatus: String,
      note: String,
      expiresAt: Date,
      changedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
      changedAt: { type: Date, default: Date.now },
    }],
    // Version history (PRD 29): a re-upload points at the file it replaces,
    // and the replaced file points forward. Old versions are never deleted.
    replaces: { type: mongoose.Schema.Types.ObjectId, ref: "Document" },
    supersededBy: { type: mongoose.Schema.Types.ObjectId, ref: "Document" },
    // A certified translation uploaded for another document of the student.
    translationOf: { type: mongoose.Schema.Types.ObjectId, ref: "Document" },
    passportReview: { type: new mongoose.Schema({
      extracted: passportFieldsSchema, reviewed: passportFieldsSchema,
      correctedFields: [String], clientReportedMrzChecksPassed: Boolean,
      manualReviewRequired: { type: Boolean, default: true },
      consentRecordedAt: Date,
    }, { _id: false }) },
  },
  { timestamps: true }
);

documentSchema.index({ expiresAt: 1, detailedStatus: 1 });
documentSchema.index({ student: 1, translationOf: 1 });
documentSchema.index({ student: 1, type: 1, fileHash: 1, size: 1 });
documentSchema.index({ student: 1, archivedAt: 1, createdAt: -1 });

function clientDocument(document) {
  const result = { ...document };
  const privatePath = `/api/documents/${result._id}/access`;
  if (result.filePath !== privatePath) result.uploadStatus = 'unavailable';
  result.filePath = privatePath;
  delete result.storage;
  delete result.legacyFilePath;
  return result;
}
documentSchema.statics.clientView = clientDocument;
documentSchema.set('toJSON', { transform: (_, document) => clientDocument(document) });
documentSchema.set('toObject', { transform: (_, document) => clientDocument(document) });

documentSchema.statics.parsePassportReview = function (input) {
  if (typeof input !== "string" || input.length > 5000) throw new Error("Invalid passport review");
  const data = JSON.parse(input);
  const readFields = (value) => {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid passport fields");
    const output = {};
    for (const [key, pattern] of Object.entries({ number: /^[A-Z0-9]{1,9}$/, name: /^.{1,200}$/u,
      nationality: /^[A-Z]{3}$/, birth: /^\d{4}-\d{2}-\d{2}$/, expiry: /^\d{4}-\d{2}-\d{2}$/, sex: /^[MF<]$/ })) {
      if (typeof value[key] !== "string" || !pattern.test(value[key].trim())) throw new Error("Invalid passport field");
      output[key] = value[key].trim();
    }
    for (const key of ["birth", "expiry"]) {
      const date = new Date(`${output[key]}T00:00:00Z`);
      if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== output[key]) throw new Error("Invalid passport date");
    }
    if (output.birth >= output.expiry || output.birth > new Date().toISOString().slice(0, 10)) throw new Error("Inconsistent dates");
    return output;
  };
  const extracted = readFields(data.extracted), reviewed = readFields(data.reviewed);
  return { extracted, reviewed, correctedFields: Object.keys(extracted).filter(key => extracted[key] !== reviewed[key]),
    clientReportedMrzChecksPassed: data.clientReportedMrzChecksPassed === true,
    manualReviewRequired: true, consentRecordedAt: new Date() };
};

const { DOCUMENT_DETAILED_TO_LEGACY_STATUS } = require("../constants/roles");

documentSchema.pre("save", function syncLegacyStatus(next) {
  if (this.isModified("detailedStatus")) {
    const legacyStatus = DOCUMENT_DETAILED_TO_LEGACY_STATUS[this.detailedStatus];
    if (legacyStatus) {
      this.status = legacyStatus;
    }
  }
  if (this.isModified("status") && !this.isModified("detailedStatus")) {
    const detailByLegacy = {"pending": "uploaded", "verified": "approved", "rejected": "rejected"};
    if (detailByLegacy[this.status]) this.detailedStatus = detailByLegacy[this.status];
  }
  next();
});

module.exports = mongoose.model("Document", documentSchema);
