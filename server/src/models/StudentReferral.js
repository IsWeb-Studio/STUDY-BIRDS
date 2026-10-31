const mongoose = require("mongoose");

const studentReferralSchema = new mongoose.Schema(
  {
    referrer: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    // A person is referred at most once — the first valid code they register
    // with wins; later codes on the same account are ignored.
    referredUser: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, unique: true },
    code: { type: String, required: true, trim: true },
    kind: { type: String, enum: ['student','agent'], default: 'student' },
    rewardAmount: { type: Number, min: 0 },
    status: { type: String, enum: ["pending", "qualified"], default: "pending", index: true },
    qualifiedAt: Date,
  },
  { timestamps: true }
);

module.exports = mongoose.model("StudentReferral", studentReferralSchema);
