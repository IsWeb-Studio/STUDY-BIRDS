const mongoose = require("mongoose");
const asyncHandler = require("../utils/asyncHandler");
const StudentReferral = require("../models/StudentReferral");
const StudentWalletEntry = require("../models/StudentWalletEntry");
const Invoice = require("../models/Invoice");
const { ensureReferralCode, getWalletBalance } = require("../utils/studentWallet");
const { withLease } = require("../utils/leaseLock");

// ---- Student: their own wallet ------------------------------------------

const { getMyRewards } = require('./studentRewardsController');

const getMyWallet = asyncHandler(async (req, res) => {
  const [referralCode, balance, referrals, transactions] = await Promise.all([
    ensureReferralCode(req.user._id),
    getWalletBalance(req.user._id),
    StudentReferral.find({ referrer: req.user._id }).populate("referredUser", "name").sort({ createdAt: -1 }).lean(),
    StudentWalletEntry.find({ student: req.user._id }).sort({ createdAt: -1 }).limit(100).lean(),
  ]);
  res.json({
    referralCode, balance,
    referrals: referrals.map((r) => ({ _id: r._id, name: r.referredUser?.name || "طالب", status: r.status, createdAt: r.createdAt, qualifiedAt: r.qualifiedAt })),
    transactions,
  });
});

const redeemWalletCredit = asyncHandler(async (req, res) => {
  const { invoiceId, amount } = req.body;
  if (!mongoose.isValidObjectId(invoiceId) || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ message: "Invalid redemption request" });
  }
  // One redemption at a time per student: the balance check, the debit and the
  // invoice update run under the student's wallet lease, so two simultaneous
  // requests can't both spend the same balance.
  const result = await withLease(`wallet:${req.user._id}`, async () => {
    const invoice = await Invoice.findOne({ _id: invoiceId, student: req.user._id });
    if (!invoice) return { status: 404, body: { message: "Invoice not found" } };
    if (invoice.stripeCheckoutExpiresAt > new Date()) return { status: 409, body: { message: 'توجد عملية دفع بالبطاقة قيد الانتظار؛ انتظر انتهاءها قبل استخدام الرصيد.' } };
    if ((invoice.currency || 'USD').toUpperCase() !== 'USD') return { status: 400, body: { message: 'رصيد المحفظة بالدولار ويستخدم لفواتير الدولار فقط.' } };
    if (invoice.status !== "unpaid") return { status: 409, body: { message: "This invoice can no longer accept credit" } };
    const remaining = invoice.amount - invoice.walletCreditApplied - (invoice.crmPaidAmount || 0);
    if (amount > remaining) return { status: 400, body: { message: "Amount exceeds what is still owed on this invoice" } };
    const balance = await getWalletBalance(req.user._id);
    if (amount > balance) return { status: 409, body: { message: "Insufficient wallet balance" } };

    // Debit first: if the invoice update then fails, the debit is removed, so
    // an invoice is never credited without a matching debit.
    const debit = await StudentWalletEntry.create({ student: req.user._id, direction: "debit", kind: "redemption", amount, relatedInvoice: invoice._id, notes: `سداد جزئي/كامل لفاتورة ${invoice.invoiceNumber}` });
    let updated = null;
    try {
      updated = await Invoice.findOneAndUpdate(
        { _id: invoice._id, status: "unpaid", walletCreditApplied: invoice.walletCreditApplied },
        { $inc: { walletCreditApplied: amount }, $set: amount >= remaining ? { status: "paid", reviewedAt: new Date() } : {} },
        { new: true }
      );
    } finally {
      if (!updated) await StudentWalletEntry.deleteOne({ _id: debit._id });
    }
    if (!updated) return { status: 409, body: { message: "Invoice changed. Refresh and retry." } };
    return { status: 200, body: { invoice: updated, balance: await getWalletBalance(req.user._id) } };
  });
  res.status(result.status).json(result.body);
});

// ---- Staff: manual adjustments (mounted under /admin/student-financials,
// gated by the existing 'student-financials' section) --------------------

const getWalletEntriesAdmin = asyncHandler(async (req, res) => {
  const query = {};
  if (req.query.student && mongoose.isValidObjectId(req.query.student)) query.student = req.query.student;
  const entries = await StudentWalletEntry.find(query).populate("student", "name email").populate("createdBy", "name").sort({ createdAt: -1 }).limit(300).lean();
  res.json(entries);
});

const createWalletAdjustmentAdmin = asyncHandler(async (req, res) => {
  const { studentId, direction, amount, notes = "" } = req.body;
  if (!mongoose.isValidObjectId(studentId) || !["credit", "debit"].includes(direction)
    || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0
    || typeof notes !== "string" || !notes.trim() || notes.length > 500) {
    return res.status(400).json({ message: "Invalid wallet adjustment" });
  }
  // Same lease as student redemptions, so a staff debit and a redemption can't
  // both pass the balance check.
  const entry = await withLease(`wallet:${studentId}`, async () => {
    if (direction === "debit" && amount > (await getWalletBalance(studentId))) return null;
    return StudentWalletEntry.create({ student: studentId, direction, kind: "adjustment", amount, notes: notes.trim(), createdBy: req.user._id });
  });
  if (!entry) return res.status(409).json({ message: "Adjustment would leave a negative balance" });
  res.status(201).json(entry);
});

module.exports = { getMyRewards, getMyWallet, redeemWalletCredit, getWalletEntriesAdmin, createWalletAdjustmentAdmin };
