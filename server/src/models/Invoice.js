const mongoose = require("mongoose");

const invoiceSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    application: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Application",
    },
    invoiceNumber: {
      type: String,
      required: true,
      trim: true,
      unique: true,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    dueDate: Date,
    status: {
      type: String,
      enum: ["unpaid", "pending-confirmation", "paid", "rejected"],
      default: "unpaid",
      index: true,
    },
    invoiceUrl: String,
    walletCreditApplied: { type: Number, default: 0, min: 0 },
    category: {
      type: String,
      enum: ["application-fee", "tuition", "service", "housing", "other"],
      default: "other",
    },
    adminNote: String,
    reviewedAt: Date,
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    stripeSessionId: { type: String },
    currency: { type: String, default: 'USD', uppercase: true },
    stripeCheckoutExpiresAt: Date,
    stripeExpectedAmount: Number,
    stripeExpectedCurrency: String,
    stripeCheckoutUrl: String,
  },
  { timestamps: true }
);

invoiceSchema.index({ student: 1, createdAt: -1 });

module.exports = mongoose.model("Invoice", invoiceSchema);
