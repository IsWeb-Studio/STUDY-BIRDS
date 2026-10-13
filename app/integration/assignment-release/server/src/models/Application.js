const mongoose = require("mongoose");
const {
  ALL_APPLICATION_STATUSES,
  APPLICATION_STATUS_TO_DETAILED_STATUS,
  APPLICATION_DETAILED_TO_LEGACY_STATUS,
} = require("../constants/roles");

const timelineSchema = new mongoose.Schema(
  {
    status: {
      type: String,
      required: true,
    },
    note: String,
    changedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    changedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: false }
);

const applicantEnglishTestSchema = new mongoose.Schema(
  {
    exam: String,
    score: String,
  },
  { _id: false }
);

const applicantProfileSchema = new mongoose.Schema(
  {
    name: String,
    email: String,
    phone: String,
    dateOfBirth: Date,
    nationality: String,
    currentEducation: String,
    gpa: String,
    intake: String,
    address: String,
    englishTest: applicantEnglishTestSchema,
  },
  { _id: false }
);

const applicationSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    program: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Program",
      required: true,
    },
    university: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "University",
      required: true,
    },
    assignedAdvisor: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    followUpDueAt: { type: Date, default: null },
    assignmentHistory: [{ advisor: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, dueAt: Date, changedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, changedAt: { type: Date, default: Date.now }, source: { type: String, enum: ['manual', 'automatic'], default: 'manual' } }],
    documents: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Document",
      },
    ],
    documentRequests: [{
      type: { type: String, required: true },
      note: { type: String, required: true, maxlength: 2000 },
      status: { type: String, enum: ['requested', 'submitted', 'approved', 'cancelled'], default: 'requested' },
      requestedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
      requestedAt: { type: Date, default: Date.now },
      document: { type: mongoose.Schema.Types.ObjectId, ref: 'Document' },
      submittedAt: Date, reviewedAt: Date,
      reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    }],
    documentRevisions: [{
      type: { type: String, required: true },
      previousDocuments: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Document' }],
      document: { type: mongoose.Schema.Types.ObjectId, ref: 'Document', required: true },
      changedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
      changedAt: { type: Date, default: Date.now },
    }],
    requiredDocumentTypes: { type: [String], default: undefined },
    applicantProfile: applicantProfileSchema,
    notes: String,
    status: {
      type: String,
      enum: ALL_APPLICATION_STATUSES,
      default: "submitted",
    },
    // Detailed lifecycle used by the mobile app, synchronized with website
    // review actions by the pre-save hook below.
    detailedStatus: {
      type: String,
      enum: [
        "draft",
        "documents-missing",
        "ready-to-apply",
        "submitted",
        "under-review",
        "additional-documents-required",
        "conditional-admission",
        "payment-required",
        "payment-verification",
        "final-admission",
        "visa-preparation",
        "completed",
        "accepted",
        "rejected",
      ],
      default: "submitted",
    },
    statusTimeline: [timelineSchema],
    submittedAt: {
      type: Date,
      default: Date.now,
    },
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  },
  { timestamps: true }
);

applicationSchema.index({ student: 1, createdAt: -1 });
applicationSchema.index({ status: 1, createdAt: -1 });
applicationSchema.index({ detailedStatus: 1, createdAt: -1 });
applicationSchema.index({ reviewedBy: 1, updatedAt: -1 });
applicationSchema.index({ university: 1, createdAt: -1 });
applicationSchema.index({ program: 1, createdAt: -1 });
applicationSchema.index({ assignedAdvisor: 1, status: 1, createdAt: 1 });

applicationSchema.pre("save", function syncLegacyStatus(next) {
  if (this.isModified("detailedStatus")) {
    const legacyStatus = APPLICATION_DETAILED_TO_LEGACY_STATUS[this.detailedStatus];
    if (legacyStatus) {
      this.status = legacyStatus;
    }
  }
  if (this.isModified("status") && !this.isModified("detailedStatus")) {
    const detailedStatus = APPLICATION_STATUS_TO_DETAILED_STATUS[this.status];
    if (detailedStatus) this.detailedStatus = detailedStatus;
  }
  next();
});

module.exports = mongoose.model("Application", applicationSchema);
