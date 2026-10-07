const mongoose = require("mongoose");

const studentInsuranceSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
      index: true,
    },
    provider: String,
    policyNumber: String,
    coverage: String,
    startDate: Date,
    endDate: Date,
    cardFileUrl: String,
    status: {
      type: String,
      enum: ["pending", "active", "expired"],
      default: "pending",
    },
    notes: String,
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("StudentInsurance", studentInsuranceSchema);
