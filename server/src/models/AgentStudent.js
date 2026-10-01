const mongoose = require("mongoose");

const agentStudentDocumentSchema = new mongoose.Schema(
  {
    label: {
      type: String,
      required: true,
      trim: true,
    },
    fileName: {
      type: String,
      required: true,
      trim: true,
    },
    filePath: {
      type: String,
      required: true,
      trim: true,
    },
    mimeType: String,
    size: Number,
    uploadedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: true }
);

const agentStudentSchema = new mongoose.Schema(
  {
    agent: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    passportNumber: {
      type: String,
      trim: true,
    },
    studyPreferences: {
      type: String,
      trim: true,
    },
    desiredUniversity: {
      type: String,
      trim: true,
    },
    desiredProgram: {
      type: String,
      trim: true,
    },
    notes: {
      type: String,
      trim: true,
    },
    applicationStatus: {
      type: String,
      enum: ["under-review", "preliminary-accepted", "final-accepted", "rejected"],
      default: "under-review",
    },
    country: {
      type: String,
      trim: true,
    },
    applicationStage: {
      type: String,
      enum: ["initial", "documents", "submitted", "admission", "visa", "enrolled"],
      default: "initial",
    },
    documents: [agentStudentDocumentSchema],
  },
  { timestamps: true }
);

agentStudentSchema.index({ agent: 1, createdAt: -1 });
agentStudentSchema.index({ agent: 1, applicationStatus: 1, createdAt: -1 });

module.exports = mongoose.model("AgentStudent", agentStudentSchema);
