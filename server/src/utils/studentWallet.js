// Student referral codes, the referral-qualification trigger, and wallet
// balance math. See STUDENT_WALLET.md for scope and the redemption model.
const crypto = require("crypto");
const mongoose = require("mongoose");
const User = require("../models/User");
const StudentReferral = require("../models/StudentReferral");
const StudentWalletEntry = require("../models/StudentWalletEntry");
const { financialTransaction } = require('./financialTransaction');
const { minorUnits } = require('./financialPolicy');
const { enqueueFinancialNotice, drainFinancialOutbox } = require('./financialOutbox');

const REFERRAL_REWARD_AMOUNT = process.env.STUDENT_REFERRAL_REWARD_AMOUNT === undefined ? 15 : Number(process.env.STUDENT_REFERRAL_REWARD_AMOUNT);

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
  const candidate = await StudentReferral.findOne({ referredUser: referredUserId }).lean();
  if (!candidate) return null;
  const reward = minorUnits(REFERRAL_REWARD_AMOUNT) / 100;
  const result = await financialTransaction([`wallet:${candidate.referrer}`], async session => {
    const referral = await StudentReferral.findById(candidate._id).session(session);
    if (!referral || !await require('../models/Application').exists({ student: referredUserId }).session(session)) return null;
    const existing = await StudentWalletEntry.findOne({ relatedReferral: referral._id, kind: 'referral-reward' }).session(session);
    if (!existing) {
      await StudentWalletEntry.create([{
        student: referral.referrer, direction: 'credit', kind: 'referral-reward', amount: reward,
        relatedReferral: referral._id, operationKey: `referral:${referral._id}`, notes: 'Referral application reward',
      }], { session });
      await enqueueFinancialNotice(`referral:${referral._id}`, {
        user: referral.referrer, title: 'Referral reward', message: `Referral credit: ${reward} USD`, link: '/student/wallet',
      }, session);
    }
    referral.status = 'qualified';
    referral.qualifiedAt = referral.qualifiedAt || new Date();
    await referral.save({ session });
    return referral;
  });
  await drainFinancialOutbox().catch(() => {});
  return result;
}

// Also repairs legacy qualified referrals whose ledger write failed. Candidate
// filtering prevents old successful referrals from starving the retry queue.
async function reconcileReferralRewards() {
  const rows = await StudentReferral.aggregate([
    { $lookup: { from: StudentWalletEntry.collection.name, localField: '_id', foreignField: 'relatedReferral', as: 'rewards' } },
    { $match: { 'rewards.0': { $exists: false } } },
    { $lookup: { from: 'applications', localField: 'referredUser', foreignField: 'student', as: 'applications' } },
    { $match: { 'applications.0': { $exists: true } } }, { $limit: 50 },
    { $project: { referredUser: 1 } },
  ]);
  for (const row of rows) await qualifyReferral(row.referredUser);
}

async function getWalletBalance(studentId, session = null) {
  const [result] = await StudentWalletEntry.aggregate([
    { $match: { student: new mongoose.Types.ObjectId(studentId) } },
    { $project: { direction: 1, scaled: { $multiply: ['$amount', 100] } } },
    { $project: { direction: 1, cents: { $round: ['$scaled', 0] },
      invalid: { $gt: [{ $abs: { $subtract: ['$scaled', { $round: ['$scaled', 0] }] } }, 0.000001] } } },
    { $group: { _id: null,
      balance: { $sum: { $cond: [{ $eq: ['$direction', 'credit'] }, '$cents', { $multiply: ['$cents', -1] }] } },
      invalid: { $sum: { $cond: ['$invalid', 1, 0] } },
    } },
  ]).session(session);
  if (result && (result.invalid || !Number.isSafeInteger(result.balance))) {
    throw Object.assign(new Error('Wallet history requires financial reconciliation'), { statusCode: 503 });
  }
  return (result?.balance || 0) / 100;
}

module.exports = { REFERRAL_REWARD_AMOUNT, ensureReferralCode, recordReferralSignup, qualifyReferral, reconcileReferralRewards, getWalletBalance };
