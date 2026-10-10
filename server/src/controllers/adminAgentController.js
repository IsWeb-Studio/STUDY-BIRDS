const mongoose = require('mongoose');
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const AgentStudent = require("../models/AgentStudent");
const MarketingAsset = require("../models/MarketingAsset");
const PayoutRequest = require("../models/PayoutRequest");
const SupportTicket = require("../models/SupportTicket");
const VerificationDocument = require("../models/VerificationDocument");
const KnowledgeBaseItem = require("../models/KnowledgeBaseItem");
const AgentWalletEntry = require("../models/AgentWalletEntry");
const Notification = require("../models/Notification");
const asyncHandler = require("../utils/asyncHandler");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");
const { sendPushToUser } = require("../utils/pushNotifications");
const { hasSection } = require("../middleware/employeeAccess");

const getPartnersAdmin = asyncHandler(async (req, res) => {
  const partners = await User.find({ role: "partner" }).select("-password").sort({ createdAt: -1 }).lean();
  const profiles = await StudentProfile.find({ user: { $in: partners.map((partner) => partner._id) } }).lean();
  const profileMap = new Map(profiles.map((profile) => [String(profile.user), profile]));

  res.json(
    partners.map((partner) => ({
      ...partner,
      profile: profileMap.get(String(partner._id)) || null,
    }))
  );
});

const getPartnerStudentsAdmin = asyncHandler(async (req, res) => {
  const students = await AgentStudent.find({ agent: req.params.id }).sort({ createdAt: -1 });
  res.json(students);
});

const getAllPartnerStudentsAdmin = asyncHandler(async (req, res) => {
  const students = await AgentStudent.find()
    .populate("agent", "name email")
    .sort({ createdAt: -1 });
  res.json(students);
});

const updatePartnerStudentStatusAdmin = asyncHandler(async (req, res) => {
  const student = await AgentStudent.findById(req.params.studentId);

  if (!student) {
    res.status(404);
    throw new Error("Agent student not found");
  }

  const nextStatus = String(req.body.applicationStatus || "").trim();
  if (!["under-review", "preliminary-accepted", "final-accepted", "rejected"].includes(nextStatus)) {
    res.status(400);
    throw new Error("Invalid application status");
  }

  student.applicationStatus = nextStatus;
  if (req.body.notes !== undefined) {
    student.notes = String(req.body.notes || "").trim();
  }
  await student.save();

  const statusLabelsAr = {
    "under-review": "قيد المراجعة",
    "preliminary-accepted": "قبول مبدئي",
    "final-accepted": "قبول نهائي",
    "rejected": "مرفوض",
  };
  const statusMessages = {
    "rejected": `للأسف، تم رفض ملف الطالب ${student.name}. يرجى التواصل معه لمراجعة الوضع والخطوات التالية.`,
    "preliminary-accepted": `تهانينا! حصل الطالب ${student.name} على قبول مبدئي. تابع إتمام متطلبات القبول النهائي.`,
    "final-accepted": `تهانينا! تم قبول الطالب ${student.name} قبولاً نهائياً. اكتملت العملية بنجاح.`,
    "under-review": `تم تحديث حالة ملف الطالب ${student.name} إلى قيد المراجعة.`,
  };
  await Notification.create({
    user: student.agent,
    title: `تحديث ملف ${student.name}: ${statusLabelsAr[nextStatus] || nextStatus}`,
    message: statusMessages[nextStatus] || `تم تحديث حالة الطالب ${student.name}.`,
    type: nextStatus === "rejected" ? "warning" : nextStatus === "final-accepted" || nextStatus === "preliminary-accepted" ? "success" : "info",
  });

  res.json(student);
});

const getPartnerDetailsAdmin = asyncHandler(async (req, res) => {
  const partner = await User.findOne({ _id: req.params.id, role: "partner" }).select("-password").lean();
  if (!partner) {
    res.status(404);
    throw new Error("Partner not found");
  }

  const [profile, students, payoutRequests, supportTickets, verificationDocuments, walletEntries, notifications] = await Promise.all([
    StudentProfile.findOne({ user: partner._id }).lean(),
    AgentStudent.find({ agent: partner._id }).sort({ createdAt: -1 }).lean(),
    PayoutRequest.find({ agent: partner._id }).populate("reviewedBy", "name email").sort({ createdAt: -1 }).lean(),
    SupportTicket.find({
      $or: [{ agent: partner._id }, { user: partner._id, requesterRole: "partner" }],
    })
      .populate("user", "name email role")
      .populate("agent", "name email role")
      .populate("replies.user", "name email role")
      .sort({ updatedAt: -1 })
      .lean(),
    VerificationDocument.find({ agent: partner._id }).populate("reviewedBy", "name email").sort({ createdAt: -1 }).lean(),
    AgentWalletEntry.find({ agent: partner._id }).sort({ createdAt: -1 }).lean(),
    Notification.find({ user: partner._id }).sort({ createdAt: -1 }).limit(10).lean(),
  ]);

  res.json({
    partner: {
      ...partner,
      profile: profile || null,
    },
    students,
    payoutRequests,
    supportTickets,
    verificationDocuments,
    walletEntries,
    notifications,
  });
});

const getPayoutRequestsAdmin = asyncHandler(async (req, res) => {
  const requests = await PayoutRequest.find()
    .populate("agent", "name email")
    .populate("reviewedBy", "name email")
    .sort({ createdAt: -1 });
  res.json(requests);
});

const updatePayoutRequestStatusAdmin = asyncHandler(async (req, res) => {
  const request = await PayoutRequest.findById(req.params.id);
  if (!request) {
    res.status(404);
    throw new Error("Payout request not found");
  }

  request.status = req.body.status || request.status;
  request.reviewNote = String(req.body.reviewNote || "").trim();
  request.reviewedBy = req.user._id;
  request.reviewedAt = new Date();
  await request.save();

  if (request.status === "paid") {
    await AgentWalletEntry.create({
      agent: request.agent,
      direction: "debit",
      kind: "payout",
      amount: request.amount,
      status: "paid",
      method: request.method,
      details: request.payoutDetails,
      notes: request.notes,
      paidAt: new Date(),
    });
  }

  const payoutStatusMessages = {
    approved: `تمت الموافقة على طلب سحب رصيدك بقيمة $${request.amount}. سيتم التحويل إلى طريقة الدفع المحددة قريباً.`,
    paid: `تم صرف طلب السحب الخاص بك بقيمة $${request.amount} بنجاح. تحقق من حسابك المالي.`,
    rejected: `للأسف، تم رفض طلب سحب رصيدك بقيمة $${request.amount}.${request.reviewNote ? ` السبب: ${request.reviewNote}` : ""} تواصل مع الدعم إذا احتجت مساعدة.`,
    pending: `طلب سحب رصيدك بقيمة $${request.amount} قيد المراجعة من الفريق المالي.`,
  };
  await Notification.create({
    user: request.agent,
    title: request.status === "paid" ? "✅ تم صرف رصيدك" : request.status === "rejected" ? "❌ تم رفض طلب السحب" : "تحديث طلب السحب",
    message: payoutStatusMessages[request.status] || `تم تحديث حالة طلب السحب إلى: ${request.status}.`,
    type: request.status === "rejected" ? "warning" : "success",
  });

  res.json(request);
});

const getMarketingAssetsAdmin = asyncHandler(async (req, res) => {
  const assets = await MarketingAsset.find().sort({ createdAt: -1 });
  res.json(assets);
});

const createMarketingAssetAdmin = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/marketing-assets");
  const asset = await MarketingAsset.create({
    title: String(req.body.title || "").trim(),
    description: String(req.body.description || "").trim(),
    type: String(req.body.type || "asset").trim(),
    fileName: req.file.originalname,
    fileUrl: uploadResult.url,
    published: req.body.published !== "false",
    uploadedBy: req.user._id,
  });

  res.status(201).json(asset);
});

const updateMarketingAssetAdmin = asyncHandler(async (req, res) => {
  const asset = await MarketingAsset.findByIdAndUpdate(
    req.params.id,
    {
      title: req.body.title,
      description: req.body.description,
      type: req.body.type,
      published: req.body.published,
    },
    { new: true }
  );

  if (!asset) {
    res.status(404);
    throw new Error("Marketing asset not found");
  }

  res.json(asset);
});

const deleteMarketingAssetAdmin = asyncHandler(async (req, res) => {
  const asset = await MarketingAsset.findByIdAndDelete(req.params.id);
  if (!asset) {
    res.status(404);
    throw new Error("Marketing asset not found");
  }
  res.json({ message: "Marketing asset removed" });
});

const getVerificationQueueAdmin = asyncHandler(async (req, res) => {
  const documents = await VerificationDocument.find()
    .populate("agent", "name email")
    .populate("reviewedBy", "name email")
    .sort({ createdAt: -1 });
  res.json(documents);
});

const reviewVerificationDocumentAdmin = asyncHandler(async (req, res) => {
  const document = await VerificationDocument.findById(req.params.id);
  if (!document) {
    res.status(404);
    throw new Error("Verification document not found");
  }

  const nextStatus = req.body.status;
  if (!["approved", "rejected", "pending"].includes(nextStatus)) {
    res.status(400);
    throw new Error("Invalid verification status");
  }

  document.status = nextStatus;
  document.reviewNote = String(req.body.reviewNote || "").trim();
  document.reviewedAt = new Date();
  document.reviewedBy = req.user._id;
  await document.save();

  const profile = await StudentProfile.findOne({ user: document.agent });
  if (profile) {
    profile.verificationStatus = nextStatus === "approved" ? "verified" : nextStatus === "rejected" ? "rejected" : "pending";
    profile.verificationReason = document.reviewNote || "";
    await profile.save();
  }

  const verifyMessages = {
    approved: "تمت الموافقة على وثائق التحقق من هويتك. حسابك الآن موثّق بالكامل ويمكنك الاستفادة من جميع مزايا الوكيل.",
    rejected: `تم رفض وثيقة التحقق الخاصة بك.${document.reviewNote ? ` السبب: ${document.reviewNote}` : ""} يرجى رفع وثيقة جديدة صحيحة.`,
    pending: "وثيقة التحقق قيد المراجعة من فريق Study Birds. سيتم إشعارك بالنتيجة قريباً.",
  };
  await Notification.create({
    user: document.agent,
    title: nextStatus === "approved" ? "✅ تم توثيق حسابك" : nextStatus === "rejected" ? "❌ تم رفض وثيقة التحقق" : "وثيقة التحقق قيد المراجعة",
    message: verifyMessages[nextStatus] || `تم تحديث حالة وثيقة التحقق إلى: ${nextStatus}.`,
    type: nextStatus === "rejected" ? "warning" : "success",
  });

  res.json(document);
});

const getSupportTicketsAdmin = asyncHandler(async (req, res) => {
  const tickets = await SupportTicket.find()
    .populate("user", "name email role")
    .populate("agent", "name email role")
    .populate("assignedTo", "name email employeeRole")
    .populate("replies.user", "name email role")
    .sort({ updatedAt: -1 });
  res.json(tickets);
});

const getSupportTicketAdmin = asyncHandler(async (req,res) => {
  if(!mongoose.isValidObjectId(req.params.id))return res.status(400).json({message:'معرّف التذكرة غير صالح'});
  const ticket=await SupportTicket.findById(req.params.id).populate('user agent','name email role').populate('assignedTo','name email employeeRole').populate('replies.user','name email role').lean();
  if(!ticket)return res.status(404).json({message:'التذكرة غير موجودة'});
  res.json(ticket);
});

const replySupportTicketAdmin = asyncHandler(async (req, res) => {
  const ticket = await SupportTicket.findById(req.params.id);
  if (!ticket) {
    res.status(404);
    throw new Error("Support ticket not found");
  }

  const message = String(req.body.message || "").trim();
  if (!message) {
    res.status(400);
    throw new Error("Reply message is required");
  }

  const status=req.body.status || 'answered';
  if(!['open','in-progress','answered','closed'].includes(status))return res.status(400).json({message:'حالة التذكرة غير صالحة'});
  // Append atomically so two staff replies cannot overwrite each other.
  const updated=await SupportTicket.findByIdAndUpdate(ticket._id,{$set:{status},$push:{replies:{message,fromRole:'admin',user:req.user._id}},$inc:{__v:1}},{new:true,runValidators:true});
  if(!updated)return res.status(404).json({message:'التذكرة غير موجودة'});

  await Notification.create({
    user: ticket.user || ticket.agent,
    title: "رد جديد على تذكرة الدعم",
    message: `وصل ردٌّ من فريق Study Birds على تذكرة الدعم الخاصة بك "${ticket.subject}". افتح التذكرة للاطلاع على الرد.`,
    type: "info",
  });

  res.json(updated);
});

// #44: Assign ticket to a support staff member
const assignSupportTicketAdmin = asyncHandler(async (req, res) => {
  const ticket = await SupportTicket.findById(req.params.id);
  if (!ticket) return res.status(404).json({ message: 'Support ticket not found' });
  const { assignedTo } = req.body;
  if (assignedTo !== null && assignedTo !== undefined) {
    if(!mongoose.isValidObjectId(assignedTo))return res.status(400).json({message:'معرّف الموظف غير صالح'});
    const assignee = await User.findById(assignedTo).lean();
    if (!assignee?.isActive || !hasSection(assignee, 'support')) {
      return res.status(400).json({ message: 'اختر موظف دعم مخوّلًا ونشطًا' });
    }
    ticket.assignedTo = assignee._id;
  } else {
    ticket.assignedTo = null;
  }
  await ticket.save();
  res.json(ticket);
});

// #45: Escalate / de-escalate a ticket
const escalateSupportTicketAdmin = asyncHandler(async (req, res) => {
  const ticket = await SupportTicket.findById(req.params.id);
  if (!ticket) return res.status(404).json({ message: 'Support ticket not found' });
  const escalated = Boolean(req.body.escalated);
  const note = String(req.body.escalationNote || '').trim().slice(0, 1000);
  ticket.escalated = escalated;
  ticket.escalationNote = note;
  ticket.status = escalated ? 'in-progress' : ticket.status;
  await ticket.save();
  // Notify the ticket owner
  await Notification.create({
    user: ticket.user || ticket.agent,
    title: escalated ? 'تصعيد التذكرة' : 'إلغاء تصعيد التذكرة',
    message: `تذكرتك "${ticket.subject}" ${escalated ? 'صُعِّدت للمدير.' : 'تم إلغاء تصعيدها.'}`,
    type: 'info',
  });
  res.json(ticket);
});

// #51: Mark ticket as emergency and notify all support staff
const markTicketEmergency = asyncHandler(async (req, res) => {
  const ticket = await SupportTicket.findById(req.params.id);
  if (!ticket) return res.status(404).json({ message: 'Support ticket not found' });
  ticket.isEmergency = Boolean(req.body.isEmergency);
  await ticket.save();
  if (ticket.isEmergency) {
    const staffUsers = await User.find({
      isActive: { $ne: false },
      $or: [{ role: 'admin' }, { role: 'employee', permissions: 'support' }],
    }).select('_id').lean();
    for (const staff of staffUsers) {
      sendPushToUser(staff._id, {
        title: '🚨 تذكرة طارئة',
        body: `تذكرة "${ticket.subject}" بحاجة إلى استجابة فورية`,
        link: '/admin/support',
      }).catch(() => {});
    }
  }
  res.json(ticket);
});

const getKnowledgeBaseAdmin = asyncHandler(async (req, res) => {
  const items = await KnowledgeBaseItem.find().sort({ sortOrder: 1, createdAt: -1 });
  res.json(items);
});

const createKnowledgeBaseItemAdmin = asyncHandler(async (req, res) => {
  const item = await KnowledgeBaseItem.create({
    title: String(req.body.title || "").trim(),
    body: String(req.body.body || "").trim(),
    category: String(req.body.category || "general").trim(),
    summary: String(req.body.summary || "").trim(),
    resourceType: String(req.body.resourceType || "article").trim(),
    fileUrl: String(req.body.fileUrl || "").trim(),
    videoUrl: String(req.body.videoUrl || "").trim(),
    targetRole: String(req.body.targetRole || "all").trim(),
    sortOrder: Number(req.body.sortOrder || 0),
    published: req.body.published !== false,
    updatedBy: req.user._id,
  });

  res.status(201).json(item);
});

const updateKnowledgeBaseItemAdmin = asyncHandler(async (req, res) => {
  const item = await KnowledgeBaseItem.findByIdAndUpdate(
    req.params.id,
    {
      title: req.body.title,
      body: req.body.body,
      category: req.body.category,
      summary: req.body.summary,
      resourceType: req.body.resourceType,
      fileUrl: req.body.fileUrl,
      videoUrl: req.body.videoUrl,
      targetRole: req.body.targetRole,
      sortOrder: Number(req.body.sortOrder || 0),
      published: req.body.published,
      updatedBy: req.user._id,
    },
    { new: true }
  );

  if (!item) {
    res.status(404);
    throw new Error("Knowledge base item not found");
  }

  res.json(item);
});

const deleteKnowledgeBaseItemAdmin = asyncHandler(async (req, res) => {
  const item = await KnowledgeBaseItem.findByIdAndDelete(req.params.id);
  if (!item) {
    res.status(404);
    throw new Error("Knowledge base item not found");
  }
  res.json({ message: "Knowledge base item removed" });
});

module.exports = {
  getPartnersAdmin,
  getAllPartnerStudentsAdmin,
  getPartnerStudentsAdmin,
  updatePartnerStudentStatusAdmin,
  getPartnerDetailsAdmin,
  getPayoutRequestsAdmin,
  updatePayoutRequestStatusAdmin,
  getMarketingAssetsAdmin,
  createMarketingAssetAdmin,
  updateMarketingAssetAdmin,
  deleteMarketingAssetAdmin,
  getVerificationQueueAdmin,
  reviewVerificationDocumentAdmin,
  getSupportTicketsAdmin,
  getSupportTicketAdmin,
  replySupportTicketAdmin,
  assignSupportTicketAdmin,
  escalateSupportTicketAdmin,
  markTicketEmergency,
  getKnowledgeBaseAdmin,
  createKnowledgeBaseItemAdmin,
  updateKnowledgeBaseItemAdmin,
  deleteKnowledgeBaseItemAdmin,
};
