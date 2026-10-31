const mongoose = require("mongoose");

const agentWalletEntrySchema = new mongoose.Schema(
  {
    agent: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    direction: {
      type: String,
      enum: ["credit", "debit"],
      default: "credit",
    },
    kind: {
      type: String,
      enum: ["commission", "payout", "adjustment"],
      default: "commission",
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "paid"],
      default: "pending",
    },
    operationKey: { type: String, unique: true, sparse: true },
    recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    method: String,
    details: String,
    notes: String,
    paidAt: Date,
  },
  { timestamps: true }
);

agentWalletEntrySchema.index({ agent: 1, createdAt: -1 });

module.exports = mongoose.model("AgentWalletEntry", agentWalletEntrySchema);
