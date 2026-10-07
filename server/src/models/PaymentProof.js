const mongoose = require("mongoose");

const paymentProofSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    invoice: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Invoice",
      required: true,
      index: true,
    },
    fileName: {
      type: String,
      required: true,
    },
    filePath: {
      type: String,
      required: true,
    },
    storage: { type: new mongoose.Schema({ publicId: String, resourceType: String, deliveryType: String, format: String }, { _id: false }), select: false },
    mimeType: String,
    size: Number,
    amount: Number,
    note: String,
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
      index: true,
    },
    reviewNote: String,
    reviewedAt: Date,
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    // Who uploaded this proof — may be the student themselves or a linked parent.
    paidBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
  },
  { timestamps: true }
);

paymentProofSchema.index({ student: 1, createdAt: -1 });

module.exports = mongoose.model("PaymentProof", paymentProofSchema);
