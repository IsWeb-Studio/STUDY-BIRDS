const { onPaymentApproved, advanceTo } = require("../utils/journeyAutomation");
const { sendPushToUser } = require("../utils/pushNotifications");
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const Application = require("../models/Application");
const Document = require("../models/Document");
const Invoice = require("../models/Invoice");
const PaymentProof = require("../models/PaymentProof");
const ArrivalServiceRequest = require("../models/ArrivalServiceRequest");
const FavoriteItem = require("../models/FavoriteItem");
const OrientationTestResult = require("../models/OrientationTestResult");
const SupportTicket = require("../models/SupportTicket");
const Notification = require("../models/Notification");
const asyncHandler = require("../utils/asyncHandler");
const { expireDueDocuments } = require("../utils/documentExpiry");
const { documentStatusInfo, documentStatusNotice, DOCUMENT_STATUSES_REQUIRING_REASON } = require("../constants/statusCatalog");
const { ALL_DOCUMENT_DETAILED_STATUSES, DOCUMENT_DETAILED_TO_LEGACY_STATUS } = require("../constants/roles");
const { hydrateApplicationsWithStudentProfiles } = require("../utils/hydrateApplications");

const getStudentFinancialsAdmin = asyncHandler(async (req, res) => {
  const [invoices, paymentProofs] = await Promise.all([
    Invoice.find()
      .populate("student", "name email")
      .populate("application", "status")
      .populate("reviewedBy", "name email")
      .sort({ createdAt: -1 }),
    PaymentProof.find()
      .populate("student", "name email")
      .populate("invoice", "invoiceNumber description amount status")
      .populate("reviewedBy", "name email")
      .sort({ createdAt: -1 }),
  ]);

  res.json({ invoices, paymentProofs });
});

const getStudentDocumentsAdmin = asyncHandler(async (req, res) => {
  await expireDueDocuments();
  const documents = await Document.find()
    .populate("student", "name email")
    .populate("reviewedBy", "name")
    .sort({ createdAt: -1 })
    .lean();

  res.json(documents.map((document) => ({ ...document, statusInfo: documentStatusInfo(document) })));
});

const { documentLabel } = require("../constants/documentTypes");

// Staff review of a student document: any of the 8 statuses, a reason when
// the student must act, an optional expiry date, a history entry and a
// plain-language notice to the student. `version` guards against overwriting
// a colleague's decision made in the meantime.
const reviewStudentDocumentAdmin = asyncHandler(async (req, res) => {
  const { detailedStatus, reviewNote = "", expiresAt, version } = req.body;
  if (!ALL_DOCUMENT_DETAILED_STATUSES.includes(detailedStatus) || typeof reviewNote !== "string" || reviewNote.length > 1000
    || !Number.isInteger(version) || (expiresAt !== undefined && expiresAt !== null && Number.isNaN(new Date(expiresAt).getTime()))) {
    return res.status(400).json({ message: "Invalid document review" });
  }
  const note = reviewNote.trim();
  if (DOCUMENT_STATUSES_REQUIRING_REASON.includes(detailedStatus) && !note) {
    return res.status(400).json({ message: "A reason is required so the student knows what to fix" });
  }
  const expiry = expiresAt ? new Date(expiresAt) : expiresAt === null ? null : undefined;
  if (detailedStatus === "approved" && expiry && expiry <= new Date()) {
    return res.status(400).json({ message: "An approved document cannot already be expired" });
  }
  const now = new Date();
  const set = {
    detailedStatus, status: DOCUMENT_DETAILED_TO_LEGACY_STATUS[detailedStatus], reviewNote: note,
    reviewedBy: req.user._id, reviewedAt: now,
    ...(expiry !== undefined ? { expiresAt: expiry } : {}),
  };
  const updated = await Document.findOneAndUpdate(
    { _id: req.params.id, __v: version },
    { $set: set, $inc: { __v: 1 }, $push: { reviewHistory: { detailedStatus, note, expiresAt: expiry || undefined, changedBy: req.user._id, changedAt: now } } },
    { new: true }
  ).populate("student", "name email").populate("reviewedBy", "name").lean();
  if (!updated) {
    const exists = await Document.exists({ _id: req.params.id });
    return res.status(exists ? 409 : 404).json({ message: exists ? "This document was updated by someone else. Reload and try again." : "Document not found" });
  }
  const notice = documentStatusNotice(updated, documentLabel(updated.type));
  await Notification.create({ user: updated.student._id, ...notice, link: "/student/documents" });
  sendPushToUser(updated.student._id, { title: notice.title, body: notice.message || 'تحقق من حالة مستنداتك.', link: '/student/documents' }).catch(() => {});
  // بند 115: advance journeyStage to documents-review on first employee document review
  advanceTo(updated.student._id, 'documents-review').catch(() => {});
  res.json({ ...updated, statusInfo: documentStatusInfo(updated) });
});

const getStudentNotificationsAdmin = asyncHandler(async (req, res) => {
  const notifications = await Notification.find()
    .populate("user", "name email role")
    .sort({ createdAt: -1 });

  res.json(notifications);
});

const getStudentDetailsAdmin = asyncHandler(async (req, res) => {
  const student = await User.findOne({ _id: req.params.id, role: "student" }).select("-password").lean();

  if (!student) {
    res.status(404);
    throw new Error("Student not found");
  }

  const [profile, applications, documents, invoices, paymentProofs, arrivalRequest, favorites, orientationResult, supportTickets, notifications] = await Promise.all([
    StudentProfile.findOne({ user: student._id }).lean(),
    Application.find({ student: student._id })
      .populate({
        path: "program",
        populate: { path: "university", populate: { path: "country" } },
      })
      .populate("documents")
      .populate("statusTimeline.changedBy", "name role")
      .sort({ createdAt: -1 }),
    Document.find({ student: student._id }).sort({ createdAt: -1 }).lean(),
    Invoice.find({ student: student._id })
      .populate("application", "status")
      .populate("reviewedBy", "name email")
      .sort({ createdAt: -1 })
      .lean(),
    PaymentProof.find({ student: student._id })
      .populate("invoice", "invoiceNumber description amount status")
      .populate("reviewedBy", "name email")
      .sort({ createdAt: -1 })
      .lean(),
    ArrivalServiceRequest.findOne({ student: student._id }).populate("updatedBy", "name email").lean(),
    FavoriteItem.find({ student: student._id })
      .populate({
        path: "university",
        select: "name city language tuitionRange country",
        populate: { path: "country", select: "name code slug" },
      })
      .populate({
        path: "program",
        select: "title language tuition duration degreeLevel university",
        populate: {
          path: "university",
          select: "name city country",
          populate: { path: "country", select: "name code slug" },
        },
      })
      .sort({ createdAt: -1 })
      .lean(),
    OrientationTestResult.findOne({ student: student._id }).populate("reviewedBy", "name email").lean(),
    SupportTicket.find({ user: student._id, requesterRole: "student" })
      .populate("user", "name email role")
      .populate("replies.user", "name email role")
      .sort({ updatedAt: -1 })
      .lean(),
    Notification.find({ user: student._id }).sort({ createdAt: -1 }).limit(12).lean(),
  ]);

  res.json({
    student: {
      ...student,
      profile: profile || null,
    },
    applications: await hydrateApplicationsWithStudentProfiles(applications),
    documents,
    invoices,
    paymentProofs,
    arrivalRequest,
    favorites,
    orientationResult,
    supportTickets,
    notifications,
  });
});

const createStudentInvoiceAdmin = asyncHandler(async (req, res) => {
  const studentId = String(req.body.studentId || "").trim();
  const invoiceNumber = String(req.body.invoiceNumber || "").trim();
  const description = String(req.body.description || "").trim();
  const amount = Number(req.body.amount || 0);
  const category = req.body.category || "other";

  if (!studentId || !invoiceNumber || !description || !amount) {
    res.status(400);
    throw new Error("Student, invoice number, description, and amount are required");
  }

  // Cap total invoiced amount at program tuition for tuition/application-fee categories
  if (req.body.applicationId && ['application-fee', 'tuition'].includes(category)) {
    const app = await Application.findById(req.body.applicationId).populate('program', 'tuition').lean();
    const tuition = app?.program?.tuition;
    if (tuition) {
      const [existing] = await Invoice.aggregate([
        { $match: { application: app._id, status: { $ne: 'rejected' } } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]);
      const existingTotal = existing?.total || 0;
      if (existingTotal + amount > tuition) {
        res.status(400);
        throw new Error(`المبلغ الإجمالي (${existingTotal + amount}$) يتجاوز الرسوم الدراسية للبرنامج (${tuition}$). المتبقي: ${tuition - existingTotal}$`);
      }
    }
  }

  const invoice = await Invoice.create({
    student: studentId,
    application: req.body.applicationId || undefined,
    serviceRequest: req.body.serviceRequestId || undefined,
    accommodationBooking: req.body.accommodationBookingId || undefined,
    invoiceNumber,
    description,
    amount,
    dueDate: req.body.dueDate || null,
    status: req.body.status || "unpaid",
    invoiceUrl: String(req.body.invoiceUrl || "").trim(),
    category: req.body.category || "other",
    adminNote: String(req.body.adminNote || "").trim(),
  });

  await Notification.create({
    user: studentId,
    title: "New invoice created",
    message: `A new invoice (${invoiceNumber}) has been added to your account.`,
    type: "info",
  });

  res.status(201).json(await Invoice.findById(invoice._id).populate("student", "name email"));
});

const updateStudentInvoiceAdmin = asyncHandler(async (req, res) => {
  const invoice = await Invoice.findById(req.params.id);
  if (!invoice) {
    res.status(404);
    throw new Error("Invoice not found");
  }

  if (req.body.invoiceNumber !== undefined) invoice.invoiceNumber = String(req.body.invoiceNumber || "").trim();
  if (req.body.description !== undefined) invoice.description = String(req.body.description || "").trim();
  if (req.body.amount !== undefined) invoice.amount = Number(req.body.amount || 0);
  if (req.body.dueDate !== undefined) invoice.dueDate = req.body.dueDate || null;
  const prevStatus = invoice.status;
  if (req.body.status !== undefined) invoice.status = req.body.status;
  if (req.body.invoiceUrl !== undefined) invoice.invoiceUrl = String(req.body.invoiceUrl || "").trim();
  if (req.body.category !== undefined) invoice.category = req.body.category;
  if (req.body.adminNote !== undefined) invoice.adminNote = String(req.body.adminNote || "").trim();
  invoice.reviewedAt = new Date();
  invoice.reviewedBy = req.user._id;
  await invoice.save();

  // advance journey when admin marks invoice as paid directly (without payment proof)
  if (invoice.status === "paid" && prevStatus !== "paid") {
    onPaymentApproved(invoice.student).catch(() => {});
  }

  await Notification.create({
    user: invoice.student,
    title: "Invoice updated",
    message: `Invoice ${invoice.invoiceNumber} is now marked as ${invoice.status}.`,
    type: invoice.status === "rejected" ? "warning" : "info",
  });

  res.json(await Invoice.findById(invoice._id).populate("student", "name email").populate("reviewedBy", "name email"));
});

const deleteStudentInvoiceAdmin = asyncHandler(async (req, res) => {
  const invoice = await Invoice.findById(req.params.id);
  if (!invoice) { res.status(404); throw new Error("Invoice not found"); }
  if (invoice.status === 'paid') {
    res.status(409);
    throw new Error("لا يمكن حذف فاتورة مدفوعة. غيّر حالتها أولاً إذا لزم.");
  }
  await invoice.deleteOne();
  res.json({ deleted: true, _id: req.params.id });
});

const reviewPaymentProofAdmin = asyncHandler(async (req, res) => {
  const proof = await PaymentProof.findById(req.params.id).populate("invoice");
  if (!proof) {
    res.status(404);
    throw new Error("Payment proof not found");
  }

  const nextStatus = String(req.body.status || "").trim();
  if (!["approved", "rejected", "pending"].includes(nextStatus)) {
    res.status(400);
    throw new Error("Invalid payment proof status");
  }

  proof.status = nextStatus;
  proof.reviewNote = String(req.body.reviewNote || "").trim();
  proof.reviewedAt = new Date();
  proof.reviewedBy = req.user._id;
  await proof.save();

  const invoice = await Invoice.findById(proof.invoice?._id || proof.invoice);
  if (invoice) {
    invoice.status = nextStatus === "approved" ? "paid" : nextStatus === "rejected" ? "rejected" : "pending-confirmation";
    invoice.reviewedAt = new Date();
    invoice.reviewedBy = req.user._id;
    await invoice.save();
  }

  // بند 115: auto-advance journeyStage to first-payment when payment is approved
  if (nextStatus === "approved") {
    onPaymentApproved(proof.student).catch(() => {});
  }

  const paymentPushTitle = nextStatus === 'approved' ? 'تمت الموافقة على إثبات الدفع' : nextStatus === 'rejected' ? 'تم رفض إثبات الدفع' : 'تم تحديث حالة الدفع';
  await Notification.create({
    user: proof.student,
    title: paymentPushTitle,
    message: `Your payment proof has been ${nextStatus}.`,
    type: nextStatus === "rejected" ? "warning" : "success",
  });
  sendPushToUser(proof.student, { title: paymentPushTitle, body: `تم ${nextStatus === 'approved' ? 'قبول' : nextStatus === 'rejected' ? 'رفض' : 'مراجعة'} إثبات الدفع.`, link: '/student/payments' }).catch(() => {});

  res.json(await PaymentProof.findById(proof._id).populate("student", "name email").populate("invoice", "invoiceNumber description amount status").populate("reviewedBy", "name email"));
});

const getArrivalRequestsAdmin = asyncHandler(async (req, res) => {
  const items = await ArrivalServiceRequest.find()
    .populate("student", "name email")
    .populate("updatedBy", "name email")
    .sort({ updatedAt: -1 });
  res.json(items);
});

const PICKUP_STATUSES = ["not-assigned", "assigned", "en-route", "arrived", "completed"];

const updateArrivalRequestAdmin = asyncHandler(async (req, res) => {
  const item = await ArrivalServiceRequest.findById(req.params.id);
  if (!item) {
    res.status(404);
    throw new Error("Arrival request not found");
  }

  // Per-service stage update — updates only one service's postAdmission stage
  const SERVICE_STAGE_MAP = { airportPickup: 'arrival', studentHousing: 'housing', residencePermitSupport: 'residence', visaSupport: 'visa' };
  if (req.body.serviceKey !== undefined) {
    const { serviceKey, serviceStatus } = req.body;
    const stageName = SERVICE_STAGE_MAP[serviceKey];
    if (!stageName || !item.services?.[serviceKey]) {
      res.status(400); throw new Error("Service not selected or invalid serviceKey");
    }
    if (!['completed', 'in-progress', 'not-started'].includes(serviceStatus)) {
      res.status(400); throw new Error("Invalid serviceStatus");
    }
    const now3 = new Date();
    const eligibleApp3 = await Application.findOne({
      student: item.student,
      status: { $nin: ['rejected', 'file-completed-rejected', 'file-completed-accepted'] },
      $or: [
        { detailedStatus: { $in: ['accepted', 'final-admission', 'visa-preparation'] } },
        { status: 'final-accepted' },
      ],
    }).sort({ createdAt: -1 });
    if (eligibleApp3) {
      await Application.updateOne({ _id: eligibleApp3._id }, {
        $set: { [`postAdmission.${stageName}.status`]: serviceStatus, [`postAdmission.${stageName}.updatedAt`]: now3 }
      });
    }
    item.updatedBy = req.user._id;
    await item.save();
    return res.json(await ArrivalServiceRequest.findById(item._id).populate("student", "name email").populate("updatedBy", "name email"));
  }

  const prevStatus = item.status;
  if (req.body.status !== undefined) item.status = req.body.status;
  if (req.body.adminNote !== undefined) item.adminNote = String(req.body.adminNote || "").trim();
  if (req.body.travelAlert !== undefined) item.travelAlert = String(req.body.travelAlert || "").trim();
  if (req.body.pickup !== undefined) {
    const pickup = req.body.pickup || {};
    if (pickup.status !== undefined) {
      if (!PICKUP_STATUSES.includes(pickup.status)) {
        res.status(400);
        throw new Error("Invalid pickup status");
      }
      item.pickup.status = pickup.status;
      item.pickup.confirmedAt = pickup.status === "arrived" || pickup.status === "completed" ? new Date() : item.pickup.confirmedAt;
    }
    if (pickup.driverName !== undefined) item.pickup.driverName = String(pickup.driverName || "").trim();
    if (pickup.driverPhone !== undefined) item.pickup.driverPhone = String(pickup.driverPhone || "").trim();
  }
  item.updatedBy = req.user._id;
  await item.save();

  // sync postAdmission stages so the mobile journey tracker reflects arrival status
  if (item.status === 'completed' || item.status !== prevStatus) {
    const now2 = new Date();
    const postAdmissionStatus = item.status === 'completed' ? 'completed'
      : item.status === 'in-progress' ? 'in-progress'
      : 'not-started';
    const eligibleApp = await Application.findOne({
      student: item.student,
      status: { $nin: ['rejected', 'file-completed-rejected', 'file-completed-accepted'] },
      $or: [
        { detailedStatus: { $in: ['accepted', 'final-admission', 'visa-preparation'] } },
        { status: 'final-accepted' },
      ],
    }).sort({ createdAt: -1 });
    if (eligibleApp) {
      const stageUpdate = {
        'postAdmission.travel.status': postAdmissionStatus,
        'postAdmission.travel.updatedAt': now2,
      };
      // map each selected service to its journey stage
      if (item.services?.airportPickup) {
        stageUpdate['postAdmission.arrival.status'] = postAdmissionStatus;
        stageUpdate['postAdmission.arrival.updatedAt'] = now2;
      }
      if (item.services?.studentHousing) {
        stageUpdate['postAdmission.housing.status'] = postAdmissionStatus;
        stageUpdate['postAdmission.housing.updatedAt'] = now2;
      }
      if (item.services?.residencePermitSupport) {
        stageUpdate['postAdmission.residence.status'] = postAdmissionStatus;
        stageUpdate['postAdmission.residence.updatedAt'] = now2;
      }
      await Application.updateOne({ _id: eligibleApp._id }, { $set: stageUpdate });
      if (item.status === 'completed') {
        advanceTo(item.student, 'travel').catch(() => {});
        if (item.services?.airportPickup) advanceTo(item.student, 'reception').catch(() => {});
        if (item.services?.studentHousing) advanceTo(item.student, 'accommodation').catch(() => {});
      }
    }
  }

  await Notification.create({
    user: item.student,
    title: "Arrival request updated",
    message: `Your arrival services request is now ${item.status}.`,
    type: "info",
  });

  res.json(await ArrivalServiceRequest.findById(item._id).populate("student", "name email").populate("updatedBy", "name email"));
});

const getStudentFavoritesAdmin = asyncHandler(async (req, res) => {
  const items = await FavoriteItem.find()
    .populate("student", "name email")
    .populate({
      path: "university",
      select: "name city language tuitionRange country",
      populate: { path: "country", select: "name code slug" },
    })
    .populate({
      path: "program",
      select: "title language tuition duration degreeLevel university",
      populate: {
        path: "university",
        select: "name city country",
        populate: { path: "country", select: "name code slug" },
      },
    })
    .sort({ createdAt: -1 });
  res.json(items);
});

const getOrientationResultsAdmin = asyncHandler(async (req, res) => {
  const items = await OrientationTestResult.find()
    .populate("student", "name email")
    .populate("reviewedBy", "name email")
    .sort({ updatedAt: -1 });
  res.json(items);
});

const updateOrientationResultAdmin = asyncHandler(async (req, res) => {
  const item = await OrientationTestResult.findById(req.params.id);
  if (!item) {
    res.status(404);
    throw new Error("Orientation result not found");
  }

  if (req.body.recommendationSummary !== undefined) item.recommendationSummary = String(req.body.recommendationSummary || "").trim();
  if (req.body.adminNote !== undefined) item.adminNote = String(req.body.adminNote || "").trim();
  if (Array.isArray(req.body.suggestedFields)) item.suggestedFields = req.body.suggestedFields;
  if (Array.isArray(req.body.suggestedCountries)) item.suggestedCountries = req.body.suggestedCountries;
  item.reviewedBy = req.user._id;
  await item.save();

  await Notification.create({
    user: item.student,
    title: "Orientation guidance updated",
    message: "Your orientation test guidance has been updated by the admissions team.",
    type: "info",
  });

  res.json(await OrientationTestResult.findById(item._id).populate("student", "name email").populate("reviewedBy", "name email"));
});

const syncArrivalStagesAdmin = asyncHandler(async (req, res) => {
  const completed = await ArrivalServiceRequest.find({ status: 'completed' });
  let count = 0;
  const now2 = new Date();
  for (const item of completed) {
    const eligibleApp = await Application.findOne({
      student: item.student,
      status: { $nin: ['rejected', 'file-completed-rejected', 'file-completed-accepted'] },
      $or: [
        { detailedStatus: { $in: ['accepted', 'final-admission', 'visa-preparation'] } },
        { status: 'final-accepted' },
      ],
    }).sort({ createdAt: -1 });
    if (!eligibleApp) continue;
    const stageUpdate = {
      'postAdmission.travel.status': 'completed',
      'postAdmission.travel.updatedAt': now2,
    };
    if (item.services?.airportPickup) {
      stageUpdate['postAdmission.arrival.status'] = 'completed';
      stageUpdate['postAdmission.arrival.updatedAt'] = now2;
    }
    if (item.services?.studentHousing) {
      stageUpdate['postAdmission.housing.status'] = 'completed';
      stageUpdate['postAdmission.housing.updatedAt'] = now2;
    }
    if (item.services?.residencePermitSupport) {
      stageUpdate['postAdmission.residence.status'] = 'completed';
      stageUpdate['postAdmission.residence.updatedAt'] = now2;
    }
    await Application.updateOne({ _id: eligibleApp._id }, { $set: stageUpdate });
    advanceTo(item.student, 'travel').catch(() => {});
    if (item.services?.airportPickup) advanceTo(item.student, 'reception').catch(() => {});
    if (item.services?.studentHousing) advanceTo(item.student, 'accommodation').catch(() => {});
    count++;
  }
  res.json({ synced: count });
});

module.exports = {
  getStudentDetailsAdmin,
  getStudentDocumentsAdmin,
  reviewStudentDocumentAdmin,
  getStudentNotificationsAdmin,
  getStudentFinancialsAdmin,
  createStudentInvoiceAdmin,
  updateStudentInvoiceAdmin,
  deleteStudentInvoiceAdmin,
  reviewPaymentProofAdmin,
  getArrivalRequestsAdmin,
  updateArrivalRequestAdmin,
  syncArrivalStagesAdmin,
  getStudentFavoritesAdmin,
  getOrientationResultsAdmin,
  updateOrientationResultAdmin,
};
