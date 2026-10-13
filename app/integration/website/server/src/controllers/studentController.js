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
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");
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

  // Admission progress is managed by administrators, never by a student profile update.

  const profile = await StudentProfile.findOneAndUpdate(
    { user: req.user._id },
    profilePayload,
    { new: true, upsert: true }
  ).populate("user", "-password");

  res.json(profile);
});

const uploadDocument = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("File is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/documents");

  const document = await Document.create({
    student: req.user._id,
    type: req.body.type || "general",
    fileName: req.file.originalname,
    filePath: uploadResult.url,
    mimeType: req.file.mimetype,
    size: uploadResult.bytes || req.file.size,
  });

  res.status(201).json(document);
});

const getDocuments = asyncHandler(async (req, res) => {
  const documents = await Document.find({ student: req.user._id }).sort({ createdAt: -1 });
  res.json(documents);
});

const getApplications = asyncHandler(async (req, res) => {
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
    .sort({ createdAt: -1 });

  res.json(await hydrateApplicationsWithStudentProfiles(applications));
});

const getDashboardOverview = asyncHandler(async (req, res) => {
  const [profile, applications, documents, notifications] = await Promise.all([
    StudentProfile.findOne({ user: req.user._id }).lean(),
    Application.find({ student: req.user._id })
      .populate({
        path: "program",
        populate: {
          path: "university",
          populate: { path: "country" },
        },
      })
      .sort({ createdAt: -1 })
      .lean(),
    Document.find({ student: req.user._id }).sort({ createdAt: -1 }).lean(),
    Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(5).lean(),
  ]);

  const currentStage = profile?.applicationStage || "file-received";
  const activeStageIndex = Math.max(
    0,
    STUDENT_DASHBOARD_STAGES.findIndex((stage) => stage.key === currentStage)
  );

  res.json({
    profile: profile || null,
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
      pendingPayments: 0,
      unreadNotifications: notifications.filter((item) => !item.isRead).length,
    },
    latestNotification: notifications[0] || null,
    recentApplications: applications.slice(0, 5),
    recentDocuments: documents.slice(0, 6),
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

  let attachment;
  if (req.file) {
    const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/student-support");
    attachment = {
      fileName: req.file.originalname,
      filePath: uploadResult.url,
      mimeType: req.file.mimetype,
      size: uploadResult.bytes || req.file.size,
    };
  }

  const ticket = await SupportTicket.create({
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

  res.status(201).json(ticket);
});

const getStudentKnowledgeBase = asyncHandler(async (req, res) => {
  const items = await KnowledgeBaseItem.find({
    published: true,
    targetRole: { $in: ["all", "student"] },
  }).sort({ sortOrder: 1, createdAt: -1 });

  res.json(items);
});

const getStudentFinancials = asyncHandler(async (req, res) => {
  const [invoices, paymentProofs] = await Promise.all([
    Invoice.find({ student: req.user._id }).populate("application", "status").sort({ createdAt: -1 }),
    PaymentProof.find({ student: req.user._id }).populate("invoice", "invoiceNumber description amount status").sort({ createdAt: -1 }),
  ]);

  res.json({
    summary: {
      outstandingAmount: invoices.filter((item) => item.status === "unpaid" || item.status === "rejected").reduce((sum, item) => sum + Number(item.amount || 0), 0),
      pendingConfirmationAmount: invoices.filter((item) => item.status === "pending-confirmation").reduce((sum, item) => sum + Number(item.amount || 0), 0),
      paidAmount: invoices.filter((item) => item.status === "paid").reduce((sum, item) => sum + Number(item.amount || 0), 0),
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

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/payment-proofs");
  const proof = await PaymentProof.create({
    student: req.user._id,
    invoice: invoice._id,
    fileName: req.file.originalname,
    filePath: uploadResult.url,
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

  res.status(201).json(proof);
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
  if (!["university", "program"].includes(itemType)) {
    res.status(400);
    throw new Error("Invalid favorite item type");
  }

  const universityId = itemType === "university" ? String(req.body.universityId || "").trim() : "";
  const programId = itemType === "program" ? String(req.body.programId || "").trim() : "";

  if (itemType === "university" && !universityId) {
    res.status(400);
    throw new Error("University id is required");
  }

  if (itemType === "program" && !programId) {
    res.status(400);
    throw new Error("Program id is required");
  }

  const query = itemType === "university"
    ? { student: req.user._id, itemType, university: universityId }
    : { student: req.user._id, itemType, program: programId };

  const existing = await FavoriteItem.findOne(query);
  if (existing) {
    await existing.deleteOne();
    res.json({ removed: true, id: existing._id });
    return;
  }

  if (itemType === "university") {
    const university = await University.findById(universityId).select("_id");
    if (!university) {
      res.status(404);
      throw new Error("University not found");
    }
  }

  if (itemType === "program") {
    const program = await Program.findById(programId).select("_id");
    if (!program) {
      res.status(404);
      throw new Error("Program not found");
    }
  }

  const favorite = await FavoriteItem.create({
    student: req.user._id,
    itemType,
    university: itemType === "university" ? universityId : undefined,
    program: itemType === "program" ? programId : undefined,
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
  const result = await OrientationTestResult.findOne({ student: req.user._id });
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
  const recommendationSummary = `Focus on ${suggestedFields.join(", ") || "broad academic exploration"} with ${answers.preferredLanguage || "your preferred language"} and a ${answers.studyStyle || "balanced"} study style.`;

  const result = await OrientationTestResult.findOneAndUpdate(
    { student: req.user._id },
    {
      answers,
      recommendationSummary,
      suggestedFields,
      suggestedCountries,
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
