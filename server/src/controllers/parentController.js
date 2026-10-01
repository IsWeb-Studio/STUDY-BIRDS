const asyncHandler = require("../utils/asyncHandler");
const ParentLink = require("../models/ParentLink");
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const Application = require("../models/Application");
const PaymentProof = require("../models/PaymentProof");
const Notification = require("../models/Notification");

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

  const proofs = await PaymentProof.find({ student: req.params.studentId }).sort({ createdAt: -1 });
  res.json(proofs);
});

module.exports = {
  createLinkRequest,
  getLinkRequests,
  getChildren,
  getChildOverview,
  getChildPayments,
};
