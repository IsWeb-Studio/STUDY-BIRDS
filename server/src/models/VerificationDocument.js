const mongoose = require("mongoose");

const verificationDocumentSchema = new mongoose.Schema(
  {
    agent: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ["identity", "commercial-license", "supporting-document"],
      required: true,
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
    storage: { type: new mongoose.Schema({
      publicId: String, resourceType: String, deliveryType: String, format: String,
    }, { _id: false }), select: false },
    legacyFilePath: { type: String, select: false },
    mimeType: String,
    size: Number,
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
    },
    reviewNote: String,
    reviewedAt: Date,
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  },
  { timestamps: true }
);

function clientView(document) {
  const result = { ...document };
  result.filePath = `/api/verification-documents/${result._id}/access`;
  delete result.storage;
  delete result.legacyFilePath;
  return result;
}
verificationDocumentSchema.statics.clientView = clientView;
verificationDocumentSchema.set('toJSON', { transform: (_, document) => clientView(document) });
verificationDocumentSchema.set('toObject', { transform: (_, document) => clientView(document) });

module.exports = mongoose.model("VerificationDocument", verificationDocumentSchema);
