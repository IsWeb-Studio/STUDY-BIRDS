const {crmPagination,crmPage}=require('../utils/crmPagination');
const mongoose = require("mongoose");
const asyncHandler = require("../utils/asyncHandler");
const StudentReferral = require("../models/StudentReferral");
const StudentWalletEntry = require("../models/StudentWalletEntry");
const Invoice = require("../models/Invoice");
const { ensureReferralCode, getWalletBalance } = require("../utils/studentWallet");
const { financialTransaction } = require('../utils/financialTransaction');
const { minorUnits, operationKey, outstandingMinor, hasCardAttempt, fail } = require('../utils/financialPolicy');

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
  const cents = minorUnits(amount);
  if (!cents) return res.status(400).json({ message: 'Invalid redemption amount' });
  const key = operationKey(req, `redemption:${req.user._id}`);
  const result = await financialTransaction([`wallet:${req.user._id}`, `invoice:${invoiceId}`], async session => {
    const invoice = await Invoice.findOne({ _id: invoiceId, student: req.user._id }).session(session);
    if (!invoice) return { status: 404, body: { message: 'Invoice not found' } };
    const replay = await StudentWalletEntry.findOne({ operationKey: key }).session(session);
    if (replay) {
      if (String(replay.relatedInvoice) !== String(invoice._id) || replay.amount !== amount) fail(409, 'Idempotency key has different financial data');
      return { status: 200, body: { invoice, balance: await getWalletBalance(req.user._id, session) } };
    }
    if (hasCardAttempt(invoice)) return { status: 409, body: { message: 'Resolve the card payment attempt before using wallet credit' } };
    if ((invoice.currency || 'USD').toUpperCase() !== 'USD') return { status: 400, body: { message: 'Wallet credit is USD only' } };
    if (invoice.status !== 'unpaid') return { status: 409, body: { message: 'This invoice can no longer accept credit' } };
    const remaining = outstandingMinor(invoice);
    if (cents > remaining) return { status: 400, body: { message: 'Amount exceeds the outstanding invoice balance' } };
    const balance = await getWalletBalance(req.user._id, session);
    if (cents > minorUnits(Math.max(0, balance))) return { status: 409, body: { message: 'Insufficient wallet balance' } };
    await StudentWalletEntry.create([{
      student: req.user._id, direction: 'debit', kind: 'redemption', amount,
      relatedInvoice: invoice._id, operationKey: key, notes: `Invoice ${invoice.invoiceNumber}`,
    }], { session });
    // All writers conflict on this invoice; no independent compensation on errors.
    invoice.walletCreditApplied = (minorUnits(invoice.walletCreditApplied || 0) + cents) / 100;
    if (cents === remaining) { invoice.status = 'paid'; invoice.reviewedAt = new Date(); }
    invoice.increment();
    await invoice.save({ session });
    return { status: 200, body: { invoice, balance: await getWalletBalance(req.user._id, session) } };
  });
  res.status(result.status).json(result.body);
});

// ---- Staff: manual adjustments (mounted under /admin/student-financials,
// gated by the existing 'student-financials' section) --------------------

const getWalletEntriesAdmin = asyncHandler(async (req, res) => {
  const query = {};
  if (req.query.student && mongoose.isValidObjectId(req.query.student)) query.student = req.query.student;
  const pagination=crmPagination(req.query);
  const entries = await StudentWalletEntry.find(query).populate("student", "name email").populate("createdBy", "name").sort({ createdAt: -1, _id:-1 }).skip(pagination?.skip || 0).limit(pagination?.limit || 300).lean();
  res.json(pagination?crmPage(entries,await StudentWalletEntry.countDocuments(query),pagination):entries);
});

const createWalletAdjustmentAdmin = asyncHandler(async (req, res) => {
  const { studentId, direction, amount, notes = "" } = req.body;
  if (!mongoose.isValidObjectId(studentId) || !["credit", "debit"].includes(direction)
    || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0
    || typeof notes !== "string" || !notes.trim() || notes.length > 500) {
    return res.status(400).json({ message: "Invalid wallet adjustment" });
  }
  if (!minorUnits(amount)) return res.status(400).json({ message: 'Invalid wallet amount' });
  if (!await require('../models/User').exists({ _id: studentId, role: 'student' })) return res.status(404).json({ message: 'Student not found' });
  const key = operationKey(req, `adjustment:${studentId}:${req.user._id}`);
  const entry = await financialTransaction([`wallet:${studentId}`], async session => {
    const replay = await StudentWalletEntry.findOne({ operationKey: key }).session(session);
    if (replay) {
      if (replay.direction !== direction || replay.amount !== amount || replay.notes !== notes.trim()) fail(409, 'Idempotency key has different financial data');
      return replay;
    }
    if (direction === 'debit' && amount > await getWalletBalance(studentId, session)) fail(409, 'Adjustment would leave a negative balance');
    const [created] = await StudentWalletEntry.create([{
      student: studentId, direction, kind: 'adjustment', amount, notes: notes.trim(),
      createdBy: req.user._id, operationKey: key,
    }], { session });
    return created;
  });
  res.status(201).json(entry);
});

module.exports = { getMyRewards, getMyWallet, redeemWalletCredit, getWalletEntriesAdmin, createWalletAdjustmentAdmin };
