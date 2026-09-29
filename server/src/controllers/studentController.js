const { studentJourneys } = require('../utils/studentJourney');
const mongoose = require('mongoose');
const { uploadPrivateDocument } = require('../utils/privateDocumentStorage');
const { studentNextAction } = require("../utils/studentNextAction");
const StudentProfile = require("../models/StudentProfile");
const Document = require("../models/Document");
const Application = require("../models/Application");
const AgencyRequest = require("../models/AgencyRequest");
const Notification = require("../models/Notification");
const SupportTicket = require("../models/SupportTicket");
const KnowledgeBaseItem = require("../models/KnowledgeBaseItem");
const Invoice = require("../models/Invoice");
const PaymentProof = require("../models/PaymentProof");
const ArrivalServiceRequest = require("../models/ArrivalServiceRequest");
const FavoriteItem = require("../models/FavoriteItem");
const OrientationTestResult = require("../models/OrientationTestResult");
const Program = require("../models/Program");
const University = require("../models/University");
const User = require("../models/User");
const asyncHandler = require("../utils/asyncHandler");
const { expireDueDocuments } = require("../utils/documentExpiry");
const { studentHome } = require("../utils/studentHome");
const { applicationCard } = require("../utils/applicationCard");
const AccommodationBooking = require("../models/AccommodationBooking");
const { Booking: ConsultationBooking } = require("../models/Consultation");
const { applicationStatusInfo, documentStatusInfo } = require("../constants/statusCatalog");
const {
  hydrateApplicationsWithStudentProfiles,
} = require("../utils/hydrateApplications");

const STUDENT_SUPPORT_CATEGORIES = [
  "documents",
  "application-status",
  "payment",
  "arrival-services",
  "other",
];

const STUDENT_DASHBOARD_STAGES = [
  {
    key: "file-received",
    titleAr: "تم استلام الملف",
    titleEn: "File Received",
    descriptionAr: "تم إنشاء ملفك وبدء مراجعة بياناتك الأساسية.",
    descriptionEn: "Your profile has been created and the initial information review has started.",
  },
  {
    key: "applying",
    titleAr: "قيد التقديم في الجامعة",
    titleEn: "Applying to University",
    descriptionAr: "نعمل الآن على تجهيز وإرسال طلباتك إلى الجهات المناسبة.",
    descriptionEn: "We are preparing and submitting your applications to suitable institutions.",
  },
  {
    key: "preliminary-accepted",
    titleAr: "صدر القبول المبدئي",
    titleEn: "Preliminary Acceptance",
    descriptionAr: "تم استلام قبول مبدئي ونراجع معك الخطوات التالية.",
    descriptionEn: "A preliminary acceptance has been received and the next steps are under review.",
  },
  {
    key: "first-payment",
    titleAr: "تم دفع الدفعة الأولى",
    titleEn: "First Payment Completed",
    descriptionAr: "تم تسجيل الدفعة الأولى ونستكمل إجراءات التثبيت.",
    descriptionEn: "The first payment has been recorded and confirmation steps are in progress.",
  },
  {
    key: "final-accepted",
    titleAr: "صدر القبول النهائي",
    titleEn: "Final Acceptance",
    descriptionAr: "تم إصدار القبول النهائي ويمكنك التحضير للسفر والخدمات اللاحقة.",
    descriptionEn: "Final acceptance is ready and you can prepare for travel and post-admission services.",
  },
  {
    key: "travel-and-settlement",
    titleAr: "مرحلة السفر والتثبيت",
    titleEn: "Travel & Settlement",
    descriptionAr: "مرحلة التنسيق للسفر والوصول والسكن والخدمات المساندة.",
    descriptionEn: "Travel, arrival, housing, and settlement support are being coordinated.",
  },
];

const getProfile = asyncHandler(async (req, res) => {
  const profile = await StudentProfile.findOne({ user: req.user._id }).populate(
    "user",
    "-password"
  );

  res.json(profile);
});

const updateProfile = asyncHandler(async (req, res) => {
  const {
    name,
    email,
    phone,
    englishFullName,
    passportNumber,
    dateOfBirth,
    nationality,
    currentEducation,
    currentEducationLevel,
    currentResidenceCountry,
    gpa,
    englishTest,
    targetCountries,
    intake,
    bio,
    address,
    applicationStage,
  } = req.body;

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
    const existingUser = await User.findOne({ email: normalizedEmail, _id: { $ne: req.user._id } });
    if (existingUser) {
      res.status(400);
      throw new Error("Email already in use");
    }
    user.email = normalizedEmail;
  }

  await user.save();

  const profilePayload = {
    phone,
    englishFullName: String(englishFullName || "").trim(),
    passportNumber: String(passportNumber || "").trim(),
    dateOfBirth,
    nationality,
    currentEducation,
    currentEducationLevel: String(currentEducationLevel || "").trim(),
    currentResidenceCountry: String(currentResidenceCountry || "").trim(),
    gpa,
    englishTest,
    targetCountries,
    intake,
    bio,
    address,
  };

  // Journey state is controlled by staff workflows, never by self-service profile edits.
  for (const field of ['parentInfo', 'emergencyContact']) {
    if (req.body[field] !== undefined) {
      const contact = req.body[field];
      if (!contact || typeof contact !== 'object' || Array.isArray(contact) ||
          ['name', 'phone', 'relationship'].some(key => contact[key] !== undefined &&
            (typeof contact[key] !== 'string' || contact[key].length > 200))) {
        return res.status(400).json({ message: 'Invalid contact information' });
      }
      profilePayload[field] = Object.fromEntries(['name', 'phone', 'relationship'].map(key => [key, (contact[key] || '').trim()]));
    }
  }
  if (req.body.nativeLanguage !== undefined) {
    if (typeof req.body.nativeLanguage !== 'string' || req.body.nativeLanguage.length > 100) return res.status(400).json({ message: 'Invalid language' });
    profilePayload.nativeLanguage = req.body.nativeLanguage.trim();
  }
  if (req.body.otherLanguages !== undefined) {
    if (!Array.isArray(req.body.otherLanguages) || req.body.otherLanguages.length > 30 ||
        req.body.otherLanguages.some(value => typeof value !== 'string' || value.length > 100)) return res.status(400).json({ message: 'Invalid languages' });
    profilePayload.otherLanguages = [...new Set(req.body.otherLanguages.map(value => value.trim()).filter(Boolean))];
  }

  const profile = await StudentProfile.findOneAndUpdate(
    { user: req.user._id },
    profilePayload,
    { new: true, upsert: true, runValidators: true }
  ).populate("user", "-password");

  res.json(profile);
});

const uploadDocument = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  // Optional links, checked before anything is stored: a new version of one of
  // the student's own current files, or a certified translation of one.
  const { replaces, translationOf } = req.body;
  if ((replaces && !mongoose.isValidObjectId(replaces)) || (translationOf && !mongoose.isValidObjectId(translationOf)) || (replaces && translationOf)) {
    return res.status(400).json({ message: "Invalid document link" });
  }
  const previous = replaces ? await Document.findOne({ _id: replaces, student: req.user._id }).select("type supersededBy").lean() : null;
  if (replaces && !previous) return res.status(404).json({ message: "Document to replace not found" });
  if (previous?.supersededBy) return res.status(409).json({ message: "A newer version of this document already exists" });
  const original = translationOf ? await Document.exists({ _id: translationOf, student: req.user._id }) : null;
  if (translationOf && !original) return res.status(404).json({ message: "Document to translate not found" });

  const uploadResult = await uploadPrivateDocument(req.file);
  const documentId = new mongoose.Types.ObjectId();

  const document = await Document.create({
    _id: documentId,
    storage: uploadResult,
    student: req.user._id,
    type: translationOf ? "translation" : req.body.type || previous?.type || "general",
    fileName: req.file.originalname,
    filePath: `/api/documents/${documentId}/access`,
    mimeType: req.file.mimetype,
    size: uploadResult.bytes || req.file.size,
    ...(previous ? { replaces: previous._id } : {}),
    ...(translationOf ? { translationOf } : {}),
  });
  if (previous) {
    // Guarded so two simultaneous re-uploads can't both claim the old version.
    const linked = await Document.updateOne({ _id: previous._id, supersededBy: { $exists: false } }, { supersededBy: document._id });
    if (!linked.modifiedCount) {
      await Document.updateOne({ _id: document._id }, { $unset: { replaces: 1 } });
    }
  }

  const response = (await Document.findById(document._id).lean());
  delete response.storage;
  res.status(201).json({ ...response, statusInfo: documentStatusInfo(response) });
});

// Translation state of a document (PRD 29): required by a reviewer, uploaded,
// approved, or not required.
function translationState(document, translations) {
  const latest = translations.filter((item) => !item.supersededBy).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];
  if (latest) {
    const info = documentStatusInfo(latest);
    const status = info.status === "approved" ? "approved" : ["rejected", "needs-revision", "expired"].includes(info.status) ? "needs-attention" : "uploaded";
    return { status, documentId: latest._id, statusInfo: info };
  }
  return { status: document.detailedStatus === "needs-translation" ? "required" : "not-required", documentId: null };
}

const getDocuments = asyncHandler(async (req, res) => {
  await expireDueDocuments({ student: req.user._id });
  const documents = await Document.find({ student: req.user._id }).select("-reviewHistory")
    .populate("reviewedBy", "name").sort({ createdAt: -1 }).lean();
  const byId = new Map(documents.map((document) => [String(document._id), document]));
  res.json(documents.map((document) => {
    // Older versions, newest first, by following the replaces chain.
    const versions = [];
    for (let prior = byId.get(String(document.replaces || "")); prior && versions.length < 20; prior = byId.get(String(prior.replaces || ""))) {
      versions.push({ _id: prior._id, fileName: prior.fileName, filePath: prior.filePath, createdAt: prior.createdAt, statusInfo: documentStatusInfo(prior) });
    }
    const translations = documents.filter((item) => String(item.translationOf || "") === String(document._id));
    return {
      ...document,
      reviewedBy: document.reviewedBy ? { name: document.reviewedBy.name } : undefined,
      statusInfo: documentStatusInfo(document),
      isLatest: !document.supersededBy,
      versions,
      translation: document.translationOf ? null : translationState(document, translations),
    };
  }));
});

const getApplications = asyncHandler(async (req, res) => {
  await expireDueDocuments({ student: req.user._id });
  const applications = await Application.find({ student: req.user._id })
    .populate({
      path: "program",
      populate: {
        path: "university",
        populate: { path: "country" },
      },
    })
    .populate("documents")
    .populate("statusTimeline.changedBy", "name role")
    .populate("assignedAdvisor", "name isActive")
    .sort({ createdAt: -1 });

  // Card summary per application (PRD 15/16), from the same journey logic as the home screen.
  const [documents, invoices] = await Promise.all([
    Document.find({ student: req.user._id }).select("type status detailedStatus").lean(),
    Invoice.find({ student: req.user._id }).lean(),
  ]);
  const plain = applications.map((application) => application.toObject());
  const journeys = studentJourneys({ applications: plain, documents, invoices });
  const hydrated = await hydrateApplicationsWithStudentProfiles(applications);
  res.json(hydrated.map((application, index) => {
    // The advisor's name is shown via card.consultant; don't send the raw user record.
    const { assignedAdvisor, ...visible } = application;
    return { ...visible, card: applicationCard(plain[index], journeys[index]) };
  }));
});

const getDashboardOverview = asyncHandler(async (req, res) => {
  await expireDueDocuments({ student: req.user._id });
  const [profile, applications, documents, notifications, invoices, unreadCount] = await Promise.all([
    StudentProfile.findOne({ user: req.user._id }).lean(),
    Application.find({ student: req.user._id })
      .populate('assignedAdvisor', 'name isActive')
      .populate({
        path: "program",
        populate: {
          path: "university",
          populate: { path: "country" },
        },
      })
      .sort({ createdAt: -1 })
      .lean(),
    Document.find({ student: req.user._id }).select("-reviewHistory -reviewedBy").sort({ createdAt: -1 }).lean(),
    Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(5).lean(),
    Invoice.find({ student: req.user._id }).lean(),
    Notification.countDocuments({ user: req.user._id, isRead: false }),
  ]);
  // Extra records for the home screen (travel, housing, consultations, support).
  const [arrivals, bookings, consultations, openTickets] = await Promise.all([
    ArrivalServiceRequest.find({ student: req.user._id }).select("arrivalDate status pickup.status createdAt").lean(),
    AccommodationBooking.find({ student: req.user._id }).select("moveInDate status createdAt").lean(),
    ConsultationBooking.find({ student: req.user._id, status: "booked", startsAt: { $gte: new Date() } }).select("startsAt").sort({ startsAt: 1 }).limit(3).lean(),
    SupportTicket.countDocuments({ user: req.user._id, status: { $in: ["open", "in-progress", "answered"] } }),
  ]);
  const nextAction = studentNextAction({ applications, documents, invoices });
  const journeys = studentJourneys({ applications, documents, invoices });

  const currentStage = profile?.applicationStage || "file-received";
  const activeStageIndex = Math.max(
    0,
    STUDENT_DASHBOARD_STAGES.findIndex((stage) => stage.key === currentStage)
  );

  res.json({
    profile: profile || null,
    nextAction,
    journeys,
    home: studentHome({
      user: req.user, applications, documents, invoices, arrivals, bookings, consultations, openTickets,
      unreadNotifications: unreadCount, latestNotification: notifications[0] || null, nextAction, journeys,
    }),
    progress: {
      currentStage,
      stages: STUDENT_DASHBOARD_STAGES.map((stage, index) => ({
        ...stage,
        status:
          index < activeStageIndex
            ? "completed"
            : index === activeStageIndex
              ? "current"
              : "upcoming",
      })),
    },
    stats: {
      currentApplications: applications.length,
      acceptedDocuments: documents.filter((item) => item.status === "verified").length,
      rejectedDocuments: documents.filter((item) => item.status === "rejected").length,
      pendingPayments: invoices.filter((item) => ["unpaid", "rejected"].includes(item.status)).length,
      unreadNotifications: unreadCount,
    },
    latestNotification: notifications[0] || null,
    recentApplications: applications.slice(0, 5).map((application) => ({ ...application, statusInfo: applicationStatusInfo(application) })),
    recentDocuments: documents.slice(0, 6).map((document) => ({ ...document, statusInfo: documentStatusInfo(document) })),
  });
});

const getAgencyRequest = asyncHandler(async (req, res) => {
  const agencyRequest = await AgencyRequest.findOne({ student: req.user._id })
    .populate("student", "name email role")
    .populate("reviewedBy", "name email role");

  res.json(agencyRequest);
});

const createAgencyRequest = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id);

  if (!user) {
    res.status(404);
    throw new Error("User not found");
  }

  if (user.role === "partner") {
    res.status(400);
    throw new Error("You are already a partner");
  }

  const studentNote = String(req.body.studentNote || "").trim();
  const existingRequest = await AgencyRequest.findOne({ student: req.user._id });

  if (existingRequest?.status === "pending") {
    res.status(400);
    throw new Error("Agency request already submitted");
  }

  if (existingRequest) {
    existingRequest.status = "pending";
    existingRequest.studentNote = studentNote;
    existingRequest.adminNote = "";
    existingRequest.submittedAt = new Date();
    existingRequest.reviewedAt = undefined;
    existingRequest.reviewedBy = undefined;
    await existingRequest.save();

    res.status(201).json(
      await AgencyRequest.findById(existingRequest._id)
        .populate("student", "name email role")
        .populate("reviewedBy", "name email role")
    );
    return;
  }

  const agencyRequest = await AgencyRequest.create({
    student: req.user._id,
    studentNote,
  });

  res.status(201).json(
    await AgencyRequest.findById(agencyRequest._id)
      .populate("student", "name email role")
      .populate("reviewedBy", "name email role")
  );
});

const getStudentNotifications = asyncHandler(async (req, res) => {
  const notifications = await Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(50);
  res.json(notifications);
});

const markStudentNotificationAsRead = asyncHandler(async (req, res) => {
  const notification = await Notification.findOne({ _id: req.params.id, user: req.user._id });
  if (!notification) {
    res.status(404);
    throw new Error("Notification not found");
  }

  notification.isRead = true;
  await notification.save();
  res.json(notification);
});

const getStudentSupportTickets = asyncHandler(async (req, res) => {
  const tickets = await SupportTicket.find({
    $or: [{ user: req.user._id }, { agent: req.user._id }],
  })
    .populate("replies.user", "name email role")
    .sort({ updatedAt: -1 });

  res.json(
    tickets.filter((ticket) =>
      String(ticket.requesterRole || (ticket.agent ? "partner" : "student")) === "student"
    )
  );
});

const createStudentSupportTicket = asyncHandler(async (req, res) => {
  const { subject, message, category } = req.body;

  if (!subject || !message) {
    res.status(400);
    throw new Error("Subject and message are required");
  }

  const normalizedCategory = String(category || "other").trim();
  if (!STUDENT_SUPPORT_CATEGORIES.includes(normalizedCategory)) {
    res.status(400);
    throw new Error("Invalid support ticket category");
  }

  const ticketId = new mongoose.Types.ObjectId();
  let attachment, attachmentStorage;
  if (req.file) {
    const uploadResult = await uploadPrivateDocument(req.file);
    attachmentStorage = uploadResult;
    attachment = {
      fileName: req.file.originalname,
      filePath: `/api/support-attachments/${ticketId}/access`,
      mimeType: req.file.mimetype,
      size: uploadResult.bytes || req.file.size,
    };
  }

  const ticket = await SupportTicket.create({
    _id: ticketId,
    attachmentStorage,
    user: req.user._id,
    requesterRole: "student",
    subject: String(subject).trim(),
    message: String(message).trim(),
    category: normalizedCategory,
    attachment,
    replies: [
      {
        message: String(message).trim(),
        fromRole: "student",
        user: req.user._id,
      },
    ],
  });

  const result = ticket.toObject();
  delete result.attachmentStorage;
  res.status(201).json(result);
});

const getStudentKnowledgeBase = asyncHandler(async (req, res) => {
  const items = await KnowledgeBaseItem.find({
    published: true,
    targetRole: { $in: ["all", "student"] },
  }).sort({ sortOrder: 1, createdAt: -1 });

  res.json(items);
});

const getStudentFinancials = asyncHandler(async (req, res) => {
  const [invoices, paymentProofs, applications] = await Promise.all([
    Invoice.find({ student: req.user._id }).populate("application", "status").sort({ createdAt: -1 }),
    PaymentProof.find({ student: req.user._id }).populate("invoice", "invoiceNumber description amount status").sort({ createdAt: -1 }),
    Application.find({ student: req.user._id }).populate('program', 'tuition').lean(),
  ]);

  const paidAmount = invoices.filter((item) => item.status === "paid").reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const totalProgramFees = applications.reduce((sum, app) => sum + Number(app.program?.tuition || 0), 0);

  res.json({
    summary: {
      outstandingAmount: invoices.filter((item) => item.status === "unpaid" || item.status === "rejected").reduce((sum, item) => sum + Number(item.amount || 0), 0),
      pendingConfirmationAmount: invoices.filter((item) => item.status === "pending-confirmation").reduce((sum, item) => sum + Number(item.amount || 0), 0),
      paidAmount,
      totalProgramFees,
      remainingFees: totalProgramFees > 0 ? Math.max(0, totalProgramFees - paidAmount) : null,
      invoiceCount: invoices.length,
    },
    invoices,
    paymentProofs,
  });
});

const uploadPaymentProof = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  const invoice = await Invoice.findOne({ _id: req.params.id, student: req.user._id });
  if (!invoice) {
    res.status(404);
    throw new Error("Invoice not found");
  }

  const uploadResult = await uploadPrivateDocument(req.file);
  const proofId = new mongoose.Types.ObjectId();
  const proof = await PaymentProof.create({
    _id: proofId, storage: uploadResult,
    student: req.user._id,
    invoice: invoice._id,
    fileName: req.file.originalname,
    filePath: `/api/payment-proofs/${proofId}/access`,
    mimeType: req.file.mimetype,
    size: uploadResult.bytes || req.file.size,
    amount: Number(req.body.amount || invoice.amount || 0),
    note: String(req.body.note || "").trim(),
  });

  invoice.status = "pending-confirmation";
  await invoice.save();

  await Notification.create({
    user: req.user._id,
    title: "Payment proof uploaded",
    message: `Your payment proof for invoice ${invoice.invoiceNumber} is pending review.`,
    type: "info",
  });

  const response = proof.toObject();
  delete response.storage;
  res.status(201).json(response);
});

const getArrivalServiceRequest = asyncHandler(async (req, res) => {
  const request = await ArrivalServiceRequest.findOne({ student: req.user._id });
  res.json(request);
});

const upsertArrivalServiceRequest = asyncHandler(async (req, res) => {
  const profile = await StudentProfile.findOne({ user: req.user._id }).lean();
  const currentStage = profile?.applicationStage || "file-received";

  if (!["final-accepted", "travel-and-settlement"].includes(currentStage)) {
    res.status(400);
    throw new Error("Arrival services become available after final acceptance");
  }

  const payload = {
    arrivalDate: req.body.arrivalDate || null,
    arrivalTime: String(req.body.arrivalTime || "").trim(),
    flightNumber: String(req.body.flightNumber || "").trim(),
    airport: String(req.body.airport || "").trim(),
    notes: String(req.body.notes || "").trim(),
    services: {
      airportPickup: Boolean(req.body.services?.airportPickup),
      studentHousing: Boolean(req.body.services?.studentHousing),
      residencePermitSupport: Boolean(req.body.services?.residencePermitSupport),
      visaSupport: Boolean(req.body.services?.visaSupport),
    },
    status: "submitted",
  };

  const request = await ArrivalServiceRequest.findOneAndUpdate({ student: req.user._id }, payload, {
    new: true,
    upsert: true,
  });

  await Notification.create({
    user: req.user._id,
    title: "Arrival services updated",
    message: "Your arrival and services request has been submitted for coordination.",
    type: "info",
  });

  res.json(request);
});

const getStudentFavorites = asyncHandler(async (req, res) => {
  const favorites = await FavoriteItem.find({ student: req.user._id })
    .populate({
      path: "university",
      populate: { path: "country", select: "name code slug" },
    })
    .populate({
      path: "program",
      populate: {
        path: "university",
        populate: { path: "country", select: "name code slug" },
      },
    })
    .sort({ createdAt: -1 });

  res.json(favorites);
});

const toggleStudentFavorite = asyncHandler(async (req, res) => {
  const itemType = String(req.body.itemType || "").trim();
  if (!["university", "program", "article"].includes(itemType)) {
    res.status(400);
    throw new Error("Invalid favorite item type");
  }

  const universityId = itemType === "university" ? String(req.body.universityId || "").trim() : "";
  const programId = itemType === "program" ? String(req.body.programId || "").trim() : "";
  const articleSlug = itemType === "article" ? String(req.body.articleSlug || "").trim() : "";
  const articleTitle = itemType === "article" ? String(req.body.articleTitle || "").trim() : "";

  if (itemType === "university" && !universityId) {
    res.status(400); throw new Error("University id is required");
  }
  if (itemType === "program" && !programId) {
    res.status(400); throw new Error("Program id is required");
  }
  if (itemType === "article" && !articleSlug) {
    res.status(400); throw new Error("Article slug is required");
  }

  const query = itemType === "university"
    ? { student: req.user._id, itemType, university: universityId }
    : itemType === "program"
    ? { student: req.user._id, itemType, program: programId }
    : { student: req.user._id, itemType, articleSlug };

  const existing = await FavoriteItem.findOne(query);
  if (existing) {
    await existing.deleteOne();
    res.json({ removed: true, id: existing._id });
    return;
  }

  if (itemType === "university") {
    const university = await University.findById(universityId).select("_id");
    if (!university) { res.status(404); throw new Error("University not found"); }
  }
  if (itemType === "program") {
    const program = await Program.findById(programId).select("_id");
    if (!program) { res.status(404); throw new Error("Program not found"); }
  }

  const favorite = await FavoriteItem.create({
    student: req.user._id,
    itemType,
    university: itemType === "university" ? universityId : undefined,
    program: itemType === "program" ? programId : undefined,
    articleSlug: itemType === "article" ? articleSlug : undefined,
    articleTitle: itemType === "article" ? articleTitle : undefined,
    notes: String(req.body.notes || "").trim(),
  });

  res.status(201).json(favorite);
});

const removeStudentFavorite = asyncHandler(async (req, res) => {
  const favorite = await FavoriteItem.findOne({ _id: req.params.id, student: req.user._id });
  if (!favorite) {
    res.status(404);
    throw new Error("Favorite not found");
  }

  await favorite.deleteOne();
  res.json({ message: "Favorite removed" });
});

const getOrientationTestResult = asyncHandler(async (req, res) => {
  const result = await OrientationTestResult.findOne({ student: req.user._id })
    .populate('matchedPrograms.program', 'title fieldOfStudy language degreeLevel tuition university')
    .lean();
  res.json(result);
});

const submitOrientationTest = asyncHandler(async (req, res) => {
  const answers = {
    favoriteSubjects: Array.isArray(req.body.favoriteSubjects) ? req.body.favoriteSubjects : [],
    interestedFields: Array.isArray(req.body.interestedFields) ? req.body.interestedFields : [],
    studyStyle: String(req.body.studyStyle || "").trim(),
    preferredLanguage: String(req.body.preferredLanguage || "").trim(),
    preferredCountry: String(req.body.preferredCountry || "").trim(),
    approximateBudget: String(req.body.approximateBudget || "").trim(),
    desiredDegreeLevel: String(req.body.desiredDegreeLevel || "").trim(),
    avoidFields: Array.isArray(req.body.avoidFields) ? req.body.avoidFields : [],
  };

  const suggestedFields = answers.interestedFields.length
    ? answers.interestedFields
    : answers.favoriteSubjects.slice(0, 3);
  const suggestedCountries = answers.preferredCountry ? [answers.preferredCountry] : [];
  const recommendationSummary = suggestedFields.length
    ? `توصيات مبنية على اهتمامك بـ ${suggestedFields.join('، ')} مع تفضيل ${answers.preferredLanguage || 'أي لغة'} ومستوى ${answers.desiredDegreeLevel || 'أي درجة'}`
    : 'أجب على الأسئلة لتحصل على توصيات مخصصة';

  // #23: Score and rank matching programs
  const budgetNum = parseInt(String(answers.approximateBudget).replace(/[^\d]/g, ''), 10) || 0;
  const allPrograms = await Program.find({})
    .select('title fieldOfStudy language degreeLevel tuition university')
    .populate('university', 'name country')
    .lean();
  const scored = allPrograms.map(p => {
    let score = 0;
    const field = (p.fieldOfStudy || '').toLowerCase();
    for (const f of suggestedFields) if (field.includes(f.toLowerCase()) || f.toLowerCase().includes(field)) score += 30;
    if (answers.preferredLanguage && p.language && p.language.toLowerCase().includes(answers.preferredLanguage.toLowerCase())) score += 20;
    if (answers.desiredDegreeLevel && p.degreeLevel && p.degreeLevel.toLowerCase() === answers.desiredDegreeLevel.toLowerCase()) score += 20;
    if (budgetNum > 0 && p.tuition && p.tuition <= budgetNum) score += 10;
    for (const f of (answers.avoidFields || [])) if (field.includes(f.toLowerCase())) score -= 40;
    return { ...p, matchScore: score };
  }).filter(p => p.matchScore > 0).sort((a, b) => b.matchScore - a.matchScore).slice(0, 10);

  const result = await OrientationTestResult.findOneAndUpdate(
    { student: req.user._id },
    {
      answers,
      recommendationSummary,
      suggestedFields,
      suggestedCountries,
      matchedPrograms: scored.map(p => ({ program: p._id, score: p.matchScore })),
    },
    { new: true, upsert: true }
  );

  await Notification.create({
    user: req.user._id,
    title: "Orientation test saved",
    message: "Your orientation preferences have been recorded successfully.",
    type: "success",
  });

  res.json(result);
});

module.exports = {
  getProfile,
  updateProfile,
  uploadDocument,
  getDocuments,
  getApplications,
  getDashboardOverview,
  getAgencyRequest,
  createAgencyRequest,
  getStudentNotifications,
  markStudentNotificationAsRead,
  getStudentSupportTickets,
  createStudentSupportTicket,
  getStudentKnowledgeBase,
  getStudentFinancials,
  uploadPaymentProof,
  getArrivalServiceRequest,
  upsertArrivalServiceRequest,
  getStudentFavorites,
  toggleStudentFavorite,
  removeStudentFavorite,
  getOrientationTestResult,
  submitOrientationTest,
};
