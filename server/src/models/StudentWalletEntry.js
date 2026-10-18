const mongoose = require("mongoose");

const studentWalletEntrySchema = new mongoose.Schema(
  {
    student: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    direction: { type: String, enum: ["credit", "debit"], required: true },
    kind: { type: String, enum: ["referral-reward", "redemption", "adjustment"], required: true },
    amount: { type: Number, required: true, min: 0, validate: {
      validator: value => Number.isFinite(value) && Number.isSafeInteger(Math.round(value * 100)) && Math.abs(value * 100 - Math.round(value * 100)) <= 0.000001,
      message: 'Wallet amount must be a safe number of cents',
    } },
    notes: { type: String, default: "", trim: true, maxlength: 500 },
    relatedReferral: { type: mongoose.Schema.Types.ObjectId, ref: "StudentReferral" },
    operationKey: String,
    relatedInvoice: { type: mongoose.Schema.Types.ObjectId, ref: "Invoice" },
    // Present only for staff-issued manual adjustments; automatic entries
    // (referral rewards, redemptions) have no human author.
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true }
);

studentWalletEntrySchema.index({ student: 1, createdAt: -1 });
studentWalletEntrySchema.index({ operationKey: 1 }, { unique: true, partialFilterExpression: { operationKey: { $type: 'string' } } });

module.exports = mongoose.model("StudentWalletEntry", studentWalletEntrySchema);
