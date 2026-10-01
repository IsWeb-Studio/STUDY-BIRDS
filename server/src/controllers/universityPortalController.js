const asyncHandler = require("../utils/asyncHandler");
const Application = require("../models/Application");
const Notification = require("../models/Notification");
const FavoriteItem = require("../models/FavoriteItem");
const User = require("../models/User");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");

/**
 * CRITICAL AUTHORIZATION RULE: every query below filters by
 * `university: req.user.linkedUniversity`. A university account can never
 * see or modify an application belonging to another university, even by
 * guessing/changing the :id in the URL — the ownership check in
 * getScopedApplication (used by every :id route) enforces this server-side.
 */

const requireLinkedUniversity = (req, res) => {
  if (!req.user.linkedUniversity) {
    res.status(409);
    throw new Error("This account is not linked to a university yet. Contact Study Birds support.");
  }
  return req.user.linkedUniversity;
};

const getScopedApplication = async (req, res) => {
  const universityId = requireLinkedUniversity(req, res);
  const application = await Application.findOne({ _id: req.params.id, university: universityId })
    .populate("student", "name email avatar")
    .populate("program", "name")
    .populate("documents");

  if (!application) {
    res.status(404);
    throw new Error("Application not found");
  }
  return application;
};

const getApplications = asyncHandler(async (req, res) => {
  const universityId = requireLinkedUniversity(req, res);
  const { status } = req.query;

  const filter = { university: universityId };
  if (status) filter.status = status;

  const applications = await Application.find(filter)
    .populate("student", "name email avatar")
    .populate("program", "name")
    .sort({ createdAt: -1 });

  res.json(applications);
});

const getApplicationById = asyncHandler(async (req, res) => {
  const application = await getScopedApplication(req, res);
  res.json(application);
});

const updateApplicationStatus = asyncHandler(async (req, res) => {
  const application = await getScopedApplication(req, res);
  const { detailedStatus, note } = req.body;

  const { ALL_APPLICATION_DETAILED_STATUSES } = require("../constants/roles");
  if (!ALL_APPLICATION_DETAILED_STATUSES.includes(detailedStatus)) {
    res.status(400);
    throw new Error("Invalid status value");
  }

  application.detailedStatus = detailedStatus; // triggers the model's sync hook -> legacy `status`
  application.statusTimeline.push({ status: detailedStatus, note, changedBy: req.user._id });
  await application.save();

  await Notification.create({
    user: application.student._id || application.student,
    ...require("../constants/statusCatalog").applicationStatusNotice(application, application.program?.title),
    link: `/applications/${application._id}`,
  });

  res.json(application);
});

const requestDocument = asyncHandler(async (req, res) => {
  const application = await getScopedApplication(req, res);
  const { documentType, reason } = req.body;

  await Notification.create({
    user: application.student._id || application.student,
    title: "مستند إضافي مطلوب",
    message: reason || `الجامعة طلبت مستند: ${documentType || "غير محدد"}`,
    type: "warning",
    link: `/applications/${application._id}`,
  });

  res.json({ message: "Document request sent to student" });
});

const getFavoritesCount = asyncHandler(async (req, res) => {
  const universityId = requireLinkedUniversity(req, res);
  const count = await FavoriteItem.countDocuments({ itemType: "university", university: universityId });
  res.json({ count });
});

const uploadAvatar = asyncHandler(async (req, res) => {
  if (!req.file) { res.status(400); throw new Error("No file uploaded"); }
  const result = await uploadFileToCloudinary(req.file, "university-avatars");
  await User.findByIdAndUpdate(req.user._id, { avatar: result.secure_url || result.url });
  res.json({ avatar: result.secure_url || result.url });
});

module.exports = {
  getApplications,
  getApplicationById,
  updateApplicationStatus,
  requestDocument,
  getFavoritesCount,
  uploadAvatar,
};
