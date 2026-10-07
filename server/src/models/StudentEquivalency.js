const mongoose = require("mongoose");

const studentEquivalencySchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
      index: true,
    },
    authority: String,
    applicationNumber: String,
    status: {
      type: String,
      enum: ["not-started", "documents-collected", "submitted", "under-review", "completed", "rejected"],
      default: "not-started",
    },
    submittedAt: Date,
    expectedCompletionDate: Date,
    resultFileUrl: String,
    notes: String,
    requiredDocuments: [String],
    fees: String,
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("StudentEquivalency", studentEquivalencySchema);
