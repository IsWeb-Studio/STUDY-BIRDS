// Student referral codes, the referral-qualification trigger, and wallet
// balance math. See STUDENT_WALLET.md for scope and the redemption model.
const crypto = require("crypto");
const mongoose = require("mongoose");
const User = require("../models/User");
const StudentReferral = require("../models/StudentReferral");
const StudentWalletEntry = require("../models/StudentWalletEntry");
const Notification = require("../models/Notification");

const REFERRAL_REWARD_AMOUNT = Math.max(0, Number(process.env.STUDENT_REFERRAL_REWARD_AMOUNT) || 15);

async function ensureReferralCode(userId) {
  const current = await User.findById(userId).select("name referralCode").lean();
  if (!current) throw new Error("User not found");
  if (current.referralCode) return current.referralCode;
  const base = (current.name || "STUDENT").replace(/[^a-zA-Z]/g, "").slice(0, 8).toUpperCase() || "STUDENT";
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = `${base}${crypto.randomInt(1000, 9999)}`;
    const updated = await User.findOneAndUpdate({ _id: userId, referralCode: { $exists: false } }, { $set: { referralCode: code } }, { new: true })
      .catch((error) => { if (error.code === 11000) return null; throw error; });
    if (updated?.referralCode) return updated.referralCode;
    const recheck = await User.findById(userId).select("referralCode").lean();
    if (recheck.referralCode) return recheck.referralCode;
  }
  throw new Error("Unable to generate a unique referral code");
}

// Called when a code is entered at registration. A person can be referred
// once; the first valid code wins.
async function recordReferralSignup(referredUserId, code) {
  const trimmed = String(code || "").trim();
  if (!trimmed) return null;
  const referrer = await User.findOne({ referralCode: trimmed }).select("_id").lean();
  if (!referrer || String(referrer._id) === String(referredUserId)) return null;
  try {
    return await StudentReferral.create({ referrer: referrer._id, referredUser: referredUserId, code: trimmed });
  } catch (error) {
    if (error.code === 11000) return null; // already referred by someone else
    throw error;
  }
}

// Called after a student's first-ever application is created. Awards the
// referrer once the referred student takes this real step, not at signup.
async function qualifyReferral(referredUserId) {
  const referral = await StudentReferral.findOneAndUpdate(
    { referredUser: referredUserId, status: "pending" },
    { $set: { status: "qualified", qualifiedAt: new Date() } },
    { new: true }
  );
  if (!referral) return null;
  await StudentWalletEntry.create({
    student: referral.referrer, direction: "credit", kind: "referral-reward", amount: REFERRAL_REWARD_AMOUNT,
    notes: "مكافأة إحالة طالب قدّم أول طلب له", relatedReferral: referral._id,
  });
  await Notification.create({
    user: referral.referrer, title: "مكافأة إحالة", type: "success", link: "/student/wallet",
    message: `حصلت على رصيد ${REFERRAL_REWARD_AMOUNT} في محفظتك لأن طالبًا أحلته قدّم أول طلب له.`,
  });
  return referral;
}

async function getWalletBalance(studentId, session = null) {
  const [result] = await StudentWalletEntry.aggregate([
    { $match: { student: new mongoose.Types.ObjectId(studentId) } },
    { $group: { _id: null, balance: { $sum: { $cond: [{ $eq: ["$direction", "credit"] }, "$amount", { $multiply: ["$amount", -1] }] } } } },
  ]).session(session);
  return result?.balance || 0;
}

module.exports = { REFERRAL_REWARD_AMOUNT, ensureReferralCode, recordReferralSignup, qualifyReferral, getWalletBalance };
