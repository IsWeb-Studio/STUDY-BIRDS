const StudentProfile = require("../models/StudentProfile");
const User = require("../models/User");
const AgentStudent = require("../models/AgentStudent");
const AgentWalletEntry = require("../models/AgentWalletEntry");
const PayoutRequest = require("../models/PayoutRequest");
const ReferralEvent = require("../models/ReferralEvent");
const MarketingAsset = require("../models/MarketingAsset");
const VerificationDocument = require("../models/VerificationDocument");
const SupportTicket = require("../models/SupportTicket");
const Notification = require("../models/Notification");
const KnowledgeBaseItem = require("../models/KnowledgeBaseItem");
const ActivityLog = require("../models/ActivityLog");
const asyncHandler = require("../utils/asyncHandler");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");
const { logActivity } = require("../utils/logActivity");

const PARTNER_SUPPORT_CATEGORIES = [
  "student-application",
  "commission",
  "technical-issue",
  "other",
];

const buildReferralCode = (user) =>
  String(user?._id || "")
    .slice(-8)
    .padStart(8, "0");

const ensurePartnerProfile = async (user) => {
  const profile = await StudentProfile.findOne({ user: user._id });
  if (profile) {
    if (!profile.referralCode) {
      profile.referralCode = buildReferralCode(user);
      await profile.save();
    }
    return profile;
  }

  return StudentProfile.create({
    user: user._id,
    companyName: user.name,
    verificationStatus: "pending",
    referralCode: buildReferralCode(user),
  });
};

const getPartnerProfile = asyncHandler(async (req, res) => {
  const profile = await ensurePartnerProfile(req.user);
  const populated = await StudentProfile.findById(profile._id).populate("user", "-password");
  res.json(populated);
});

const updatePartnerProfile = asyncHandler(async (req, res) => {
  const {
    name,
    email,
    phone,
    dateOfBirth,
    nationality,
    bio,
    address,
    companyName,
    website,
    location,
    taxId,
  } = req.body;

  if (!String(companyName || "").trim() || !String(location || "").trim()) {
    res.status(400);
    throw new Error("Company name and location are required");
  }

  const user = await User.findById(req.user._id);
  if (!user) {
    res.status(404);
    throw new Error("User not found");
  }

  if (typeof name === "string" && name.trim()) {
    user.name = name.trim();
  }

  if (typeof email === "string" && email.trim()) {
    const normalizedEmail = email.toLowerCase().trim();
    if (user.twoFactorEnabled && normalizedEmail !== user.email) {
      res.status(400); throw new Error('أوقف التحقق بخطوتين برمز البريد قبل تغيير البريد الإلكتروني.');
    }
    const existingUser = await User.findOne({ email: normalizedEmail, _id: { $ne: req.user._id } });
    if (existingUser) {
      res.status(400);
      throw new Error("Email already in use");
    }
    if (user.email !== normalizedEmail) user.emailVerified = false;
    user.email = normalizedEmail;
  }

  await user.save();

  const profile = await StudentProfile.findOneAndUpdate(
    { user: req.user._id },
    {
      phone,
      dateOfBirth,
      nationality,
      bio,
      address,
      companyName: String(companyName || "").trim(),
      website: String(website || "").trim(),
      location: String(location || "").trim(),
      taxId: String(taxId || "").trim(),
    },
    { new: true, upsert: true }
  ).populate("user", "-password");

  if (!profile.referralCode) {
    profile.referralCode = buildReferralCode(user);
    await profile.save();
  }

  await logActivity(req, req.user._id, "profile.updated", "Updated partner profile");

  res.json(profile);
});

const getPartnerOverview = asyncHandler(async (req, res) => {
  const [students, totalStudents, acceptedStudents, walletEntries, payouts, notifications, profile] = await Promise.all([
    AgentStudent.find({ agent: req.user._id }).sort({ createdAt: -1 }).limit(5),
    AgentStudent.countDocuments({ agent: req.user._id }),
    AgentStudent.countDocuments({
      agent: req.user._id,
      applicationStatus: { $in: ["preliminary-accepted", "final-accepted"] },
    }),
    AgentWalletEntry.find({ agent: req.user._id }).sort({ createdAt: -1 }).limit(12),
    PayoutRequest.find({ agent: req.user._id }).sort({ createdAt: -1 }).limit(5),
    Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(5),
    ensurePartnerProfile(req.user),
  ]);
  const totalReceivedEarnings = walletEntries
    .filter((item) => item.direction === "credit" && item.status === "paid")
    .reduce((sum, item) => sum + item.amount, 0);
  const pendingEarnings = walletEntries
    .filter((item) => item.direction === "credit" && item.status === "pending")
    .reduce((sum, item) => sum + item.amount, 0);

  res.json({
    stats: {
      totalStudents,
      acceptedStudents,
      totalReceivedEarnings,
      pendingEarnings,
      verificationStatus: profile.verificationStatus || "pending",
    },
    recent: {
      latestStudent: students[0] || null,
      latestStudentStatusUpdate: students.find((item) => item.applicationStatus !== "under-review") || students[0] || null,
      latestPayoutRequest: payouts[0] || null,
      latestNotification: notifications[0] || null,
    },
  });
});

const getAgentStudents = asyncHandler(async (req, res) => {
  const students = await AgentStudent.find({ agent: req.user._id }).sort({ createdAt: -1 });
  res.json(students);
});

const createAgentStudent = asyncHandler(async (req, res) => {
  const payload = req.body;

  if (!String(payload.name || "").trim() || !String(payload.email || "").trim() || !String(payload.phone || "").trim()) {
    res.status(400);
    throw new Error("Name, email, and phone are required");
  }

  const student = await AgentStudent.create({
    agent: req.user._id,
    name: String(payload.name || "").trim(),
    email: String(payload.email || "").trim().toLowerCase(),
    phone: String(payload.phone || "").trim(),
    passportNumber: String(payload.passportNumber || "").trim(),
    studyPreferences: String(payload.studyPreferences || "").trim(),
    desiredUniversity: String(payload.desiredUniversity || "").trim(),
    desiredProgram: String(payload.desiredProgram || "").trim(),
    notes: String(payload.notes || "").trim(),
    // Acceptance is reviewed by administrators, not set by the submitting agent.
    applicationStatus: "under-review",
  });

  await logActivity(req, req.user._id, "student.created", `Added student ${student.name}`, { studentId: student._id });

  res.status(201).json(student);
});

const updateAgentStudent = asyncHandler(async (req, res) => {
  const payload = req.body;
  const student = await AgentStudent.findOne({ _id: req.params.id, agent: req.user._id });

  if (!student) {
    res.status(404);
    throw new Error("Student not found");
  }

  if (!String(payload.name || "").trim() || !String(payload.email || "").trim() || !String(payload.phone || "").trim()) {
    res.status(400);
    throw new Error("Name, email, and phone are required");
  }

  student.name = String(payload.name || "").trim();
  student.email = String(payload.email || "").trim().toLowerCase();
  student.phone = String(payload.phone || "").trim();
  student.passportNumber = String(payload.passportNumber || "").trim();
  student.studyPreferences = String(payload.studyPreferences || "").trim();
  student.desiredUniversity = String(payload.desiredUniversity || "").trim();
  student.desiredProgram = String(payload.desiredProgram || "").trim();
  student.notes = String(payload.notes || "").trim();

  await student.save();

  await logActivity(req, req.user._id, "student.updated", `Updated student ${student.name}`, { studentId: student._id });

  res.json(student);
});

const deleteAgentStudent = asyncHandler(async (req, res) => {
  const student = await AgentStudent.findOneAndDelete({ _id: req.params.id, agent: req.user._id });

  if (!student) {
    res.status(404);
    throw new Error("Student not found");
  }

  await logActivity(req, req.user._id, "student.deleted", `Deleted student ${student.name}`, { studentId: student._id });

  res.json({ message: "Student deleted successfully" });
});

const uploadAgentStudentDocument = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  const student = await AgentStudent.findOne({ _id: req.params.id, agent: req.user._id });
  if (!student) {
    res.status(404);
    throw new Error("Student not found");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/agent-students");
  const document = {
    label: String(req.body.label || req.body.type || "document").trim(),
    fileName: req.file.originalname,
    filePath: uploadResult.url,
    mimeType: req.file.mimetype,
    size: uploadResult.bytes || req.file.size,
  };

  student.documents.push(document);
  await student.save();

  await logActivity(req, req.user._id, "student.document.uploaded", `Uploaded a document for ${student.name}`, { studentId: student._id });

  res.status(201).json(student);
});

const getPartnerWallet = asyncHandler(async (req, res) => {
  const [entries, payouts] = await Promise.all([
    AgentWalletEntry.find({ agent: req.user._id }).sort({ createdAt: -1 }),
    PayoutRequest.find({ agent: req.user._id }).sort({ createdAt: -1 }),
  ]);

  const availableBalance = entries
    .filter((item) => item.direction === "credit" && item.status === "approved")
    .reduce((sum, item) => sum + item.amount, 0);
  const pendingBalance = entries
    .filter((item) => item.direction === "credit" && item.status === "pending")
    .reduce((sum, item) => sum + item.amount, 0);
  const receivedBalance = entries
    .filter((item) => item.direction === "credit" && item.status === "paid")
    .reduce((sum, item) => sum + item.amount, 0);

  res.json({
    summary: {
      availableBalance,
      pendingBalance,
      receivedBalance,
    },
    entries,
    payouts,
  });
});

const requestPayout = asyncHandler(async (req, res) => {
  const { amount, method, payoutDetails, notes } = req.body;
  const numericAmount = Number(amount);

  if (!numericAmount || numericAmount <= 0) {
    res.status(400);
    throw new Error("Valid payout amount is required");
  }

  if (!method || !payoutDetails) {
    res.status(400);
    throw new Error("Payout method and details are required");
  }

  const payout = await PayoutRequest.create({
    agent: req.user._id,
    amount: numericAmount,
    method,
    payoutDetails: String(payoutDetails).trim(),
    notes: String(notes || "").trim(),
  });

  await Notification.create({
    user: req.user._id,
    title: "Payout request submitted",
    message: `Your payout request for ${numericAmount} is pending review.`,
    type: "info",
  });

  await logActivity(req, req.user._id, "wallet.payout-requested", `Requested payout of ${numericAmount}`, { payoutId: payout._id });

  res.status(201).json(payout);
});

const getReferralSummary = asyncHandler(async (req, res) => {
  const profile = await ensurePartnerProfile(req.user);
  const events = await ReferralEvent.find({ agent: req.user._id });
  const baseUrl = String(process.env.CLIENT_URL || "https://studybirds.net").replace(/\/+$/, "");
  const referralLink = `${baseUrl}/register?ref=${profile.referralCode}`;

  const summary = {
    clicks: events.filter((event) => event.type === "click").length,
    signups: events.filter((event) => event.type === "signup").length,
    acceptedStudents: events.filter((event) => event.type === "accepted").length,
    generatedCommissions: events.filter((event) => event.type === "commission").reduce((sum, event) => sum + Number(event.amount || 0), 0),
  };

  res.json({
    referralCode: profile.referralCode,
    referralLink,
    summary,
  });
});

const getMarketingAssets = asyncHandler(async (req, res) => {
  const assets = await MarketingAsset.find({ published: true }).sort({ createdAt: -1 });
  res.json(assets);
});

const getVerificationDocuments = asyncHandler(async (req, res) => {
  const [profile, documents] = await Promise.all([
    ensurePartnerProfile(req.user),
    VerificationDocument.find({ agent: req.user._id }).sort({ createdAt: -1 }),
  ]);

  res.json({
    status: profile.verificationStatus || "pending",
    reason: profile.verificationReason || "",
    documents,
  });
});

const uploadVerificationDocument = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  const type = String(req.body.type || "").trim();
  if (!type) {
    res.status(400);
    throw new Error("Document type is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/agent-verification");
  const document = await VerificationDocument.create({
    agent: req.user._id,
    type,
    fileName: req.file.originalname,
    filePath: uploadResult.url,
    mimeType: req.file.mimetype,
    size: uploadResult.bytes || req.file.size,
  });

  await StudentProfile.findOneAndUpdate(
    { user: req.user._id },
    {
      verificationStatus: "pending",
      verificationReason: "",
    },
    { upsert: true }
  );

  await logActivity(req, req.user._id, "verification.document-uploaded", `Uploaded ${type} verification document`, { documentId: document._id });

  res.status(201).json(document);
});

const getSupportTickets = asyncHandler(async (req, res) => {
  const tickets = await SupportTicket.find({
    $or: [{ agent: req.user._id }, { user: req.user._id }],
  })
    .populate("replies.user", "name email role")
    .sort({ updatedAt: -1 });

  res.json(
    tickets.filter((ticket) =>
      String(ticket.requesterRole || "partner") === "partner"
    )
  );
});

const createSupportTicket = asyncHandler(async (req, res) => {
  const { subject, message, category } = req.body;

  if (!subject || !message) {
    res.status(400);
    throw new Error("Subject and message are required");
  }

  const normalizedCategory = String(category || "other").trim();
  if (!PARTNER_SUPPORT_CATEGORIES.includes(normalizedCategory)) {
    res.status(400);
    throw new Error("Invalid support ticket category");
  }

  let attachment;
  if (req.file) {
    const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/support-tickets");
    attachment = {
      fileName: req.file.originalname,
      filePath: uploadResult.url,
      mimeType: req.file.mimetype,
      size: uploadResult.bytes || req.file.size,
    };
  }

  const ticket = await SupportTicket.create({
    user: req.user._id,
    agent: req.user._id,
    requesterRole: "partner",
    subject: String(subject).trim(),
    message: String(message).trim(),
    category: normalizedCategory,
    attachment,
    replies: [
      {
        message: String(message).trim(),
        fromRole: "partner",
        user: req.user._id,
      },
    ],
  });

  await logActivity(req, req.user._id, "support.ticket-created", `Opened support ticket ${ticket.subject}`, { ticketId: ticket._id });

  res.status(201).json(ticket);
});

const getPartnerNotifications = asyncHandler(async (req, res) => {
  const notifications = await Notification.find({ user: req.user._id }).sort({ createdAt: -1 });
  res.json(notifications);
});

const markNotificationAsRead = asyncHandler(async (req, res) => {
  const notification = await Notification.findOne({ _id: req.params.id, user: req.user._id });
  if (!notification) {
    res.status(404);
    throw new Error("Notification not found");
  }

  notification.isRead = true;
  await notification.save();
  res.json(notification);
});

const getPartnerActivityLog = asyncHandler(async (req, res) => {
  const logs = await ActivityLog.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(100);
  res.json(logs);
});

const getKnowledgeBase = asyncHandler(async (req, res) => {
  const items = await KnowledgeBaseItem.find({ published: true }).sort({ sortOrder: 1, createdAt: -1 });
  res.json(items);
});

module.exports = {
  getPartnerProfile,
  updatePartnerProfile,
  getPartnerOverview,
  getAgentStudents,
  createAgentStudent,
  updateAgentStudent,
  deleteAgentStudent,
  uploadAgentStudentDocument,
  getPartnerWallet,
  requestPayout,
  getReferralSummary,
  getMarketingAssets,
  getVerificationDocuments,
  uploadVerificationDocument,
  getSupportTickets,
  createSupportTicket,
  getPartnerNotifications,
  markNotificationAsRead,
  getPartnerActivityLog,
  getKnowledgeBase,
};
