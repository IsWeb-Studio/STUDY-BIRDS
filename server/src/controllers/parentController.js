const asyncHandler = require("../utils/asyncHandler");
const ParentLink = require("../models/ParentLink");
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const Application = require("../models/Application");
const PaymentProof = require("../models/PaymentProof");
const Invoice = require("../models/Invoice");
const Notification = require("../models/Notification");
const mongoose = require("mongoose");
const { uploadPrivateDocument } = require("../utils/privateDocumentStorage");

/**
 * CRITICAL AUTHORIZATION RULE: every function below filters by
 * `req.user._id` as the parent AND requires status "approved" on the
 * ParentLink before touching any student data. A parent can never reach a
 * student's data by guessing/changing an ID — the link must exist and be
 * approved first, exactly like the existing AgencyRequest flow.
 */

const requireApprovedLink = async (parentId, studentId) => {
  const link = await ParentLink.findOne({
    parent: parentId,
    student: studentId,
    status: "approved",
  });
  return link;
};

const createLinkRequest = asyncHandler(async (req, res) => {
  const { studentEmail, relationship, note } = req.body;

  if (!studentEmail) {
    res.status(400);
    throw new Error("Student email is required");
  }

  const student = await User.findOne({
    email: String(studentEmail).toLowerCase().trim(),
    role: "student",
  });

  if (!student) {
    res.status(404);
    throw new Error("No student account found with that email");
  }

  const existing = await ParentLink.findOne({ parent: req.user._id, student: student._id });
  if (existing && existing.status !== "rejected") {
    res.status(400);
    throw new Error("A link request for this student already exists");
  }

  const link = existing
    ? await ParentLink.findByIdAndUpdate(
        existing._id,
        { status: "pending", relationship, parentNote: note, submittedAt: new Date(), reviewedAt: null, reviewedBy: null },
        { new: true }
      )
    : await ParentLink.create({
        parent: req.user._id,
        student: student._id,
        relationship,
        parentNote: note,
      });

  res.status(201).json(link);
});

const getLinkRequests = asyncHandler(async (req, res) => {
  const links = await ParentLink.find({ parent: req.user._id })
    .populate("student", "name email avatar")
    .sort({ createdAt: -1 });
  res.json(links);
});

const getChildren = asyncHandler(async (req, res) => {
  const links = await ParentLink.find({ parent: req.user._id, status: "approved" }).populate(
    "student",
    "name email avatar"
  );
  res.json(links.map((link) => link.student));
});

const getChildOverview = asyncHandler(async (req, res) => {
  const link = await requireApprovedLink(req.user._id, req.params.studentId);
  if (!link) {
    res.status(403);
    throw new Error("You are not linked to this student");
  }

  await link.populate("student", "name email avatar");

  const [profile, applications, notifications] = await Promise.all([
    StudentProfile.findOne({ user: req.params.studentId }).select(
      "journeyStage applicationStage targetCountries intake currentEducationLevel"
    ),
    Application.find({ student: req.params.studentId })
      .populate("university", "name city")
      .populate("program", "name")
      .select("status detailedStatus statusTimeline submittedAt university program"),
    Notification.find({ user: req.params.studentId })
      .sort({ createdAt: -1 })
      .limit(10)
      .select("title message type isRead createdAt")
      .lean(),
  ]);

  // Deliberately excluded: internal notes, reviewer identity, employee
  // assignment, and any other Study-Birds-internal-only fields — per spec,
  // a parent must never see internal/employee data.
  res.json({
    student: link.student,
    journeyStage: profile?.journeyStage || null,
    applicationStage: profile?.applicationStage || null,
    targetCountries: profile?.targetCountries || [],
    intake: profile?.intake || null,
    notifications: notifications.map((n) => ({
      _id: n._id,
      title: n.title,
      message: n.message,
      type: n.type,
      isRead: n.isRead,
      createdAt: n.createdAt,
    })),
    applications: applications.map((a) => ({
      id: a._id,
      status: a.status,
      detailedStatus: a.detailedStatus,
      statusInfo: require("../constants/statusCatalog").applicationStatusInfo(a),
      university: a.university,
      program: a.program,
      submittedAt: a.submittedAt,
      timeline: a.statusTimeline,
    })),
  });
});

const getChildPayments = asyncHandler(async (req, res) => {
  const link = await requireApprovedLink(req.user._id, req.params.studentId);
  if (!link) {
    res.status(403);
    throw new Error("You are not linked to this student");
  }

  const [invoices, proofs] = await Promise.all([
    Invoice.find({ student: req.params.studentId }).sort({ createdAt: -1 }).lean(),
    PaymentProof.find({ student: req.params.studentId })
      .populate("paidBy", "name role")
      .sort({ createdAt: -1 })
      .lean(),
  ]);

  // Attach matching proofs to each invoice
  const proofsByInvoice = {};
  for (const proof of proofs) {
    const key = proof.invoice?.toString();
    if (key) {
      if (!proofsByInvoice[key]) proofsByInvoice[key] = [];
      proofsByInvoice[key].push(proof);
    }
  }

  res.json(invoices.map((inv) => ({
    _id: inv._id,
    invoiceNumber: inv.invoiceNumber,
    description: inv.description,
    amount: inv.amount,
    currency: inv.currency || "USD",
    dueDate: inv.dueDate,
    status: inv.status,
    category: inv.category,
    proofs: (proofsByInvoice[inv._id.toString()] || []).map((p) => ({
      _id: p._id,
      status: p.status,
      amount: p.amount,
      note: p.note,
      filePath: p.filePath,
      createdAt: p.createdAt,
      paidBy: p.paidBy ? { _id: p.paidBy._id, name: p.paidBy.name, role: p.paidBy.role } : null,
    })),
  })));
});

const uploadChildPaymentProof = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  const link = await requireApprovedLink(req.user._id, req.params.studentId);
  if (!link) {
    res.status(403);
    throw new Error("You are not linked to this student");
  }

  const invoice = await Invoice.findOne({ _id: req.params.invoiceId, student: req.params.studentId });
  if (!invoice) {
    res.status(404);
    throw new Error("Invoice not found");
  }
  if (invoice.status === "paid") {
    res.status(400);
    throw new Error("This invoice is already paid");
  }

  await link.populate("student", "name");

  const uploadResult = await uploadPrivateDocument(req.file);
  const proofId = new mongoose.Types.ObjectId();
  const proof = await PaymentProof.create({
    _id: proofId,
    storage: uploadResult,
    student: req.params.studentId,
    invoice: invoice._id,
    paidBy: req.user._id,
    fileName: req.file.originalname,
    filePath: `/api/payment-proofs/${proofId}/access`,
    mimeType: req.file.mimetype,
    size: uploadResult.bytes || req.file.size,
    amount: Number(req.body.amount || invoice.amount || 0),
    note: String(req.body.note || "").trim(),
  });

  invoice.status = "pending-confirmation";
  await invoice.save();

  // Notify the student that their parent paid on their behalf
  await Notification.create({
    user: req.params.studentId,
    title: "تم رفع إثبات الدفع من قِبل ولي أمرك",
    message: `قام ${req.user.name} برفع إثبات دفع لفاتورة ${invoice.invoiceNumber} نيابةً عنك. الطلب قيد المراجعة.`,
    type: "info",
    link: "/student/payments",
  });

  const response = proof.toObject();
  delete response.storage;
  res.status(201).json(response);
});

module.exports = {
  createLinkRequest,
  getLinkRequests,
  getChildren,
  getChildOverview,
  getChildPayments,
  uploadChildPaymentProof,
};
