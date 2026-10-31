const mongoose = require("mongoose");

const payoutRequestSchema = new mongoose.Schema(
  {
    agent: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 1,
    },
    method: {
      type: String,
      enum: ["bank-account", "usdt", "wise", "other"],
      required: true,
    },
    payoutDetails: {
      type: String,
      required: true,
      trim: true,
    },
    notes: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "paid"],
      default: "pending",
    },
    operationKey: { type: String, unique: true, sparse: true },
    reviewNote: String,
    reviewedAt: Date,
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("PayoutRequest", payoutRequestSchema);
