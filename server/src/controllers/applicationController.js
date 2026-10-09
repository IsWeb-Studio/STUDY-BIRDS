const { requiredDocumentTypesFor, missingDocumentTypes } = require("../utils/applicationRequirements");
const { onApplicationStatusChange } = require("../utils/journeyAutomation");
const mongoose = require("mongoose");
const Application = require("../models/Application");
const Program = require("../models/Program");
const Document = require("../models/Document");
const Notification = require("../models/Notification");
const asyncHandler = require("../utils/asyncHandler");
const { ALL_APPLICATION_STATUSES, ALL_APPLICATION_DETAILED_STATUSES } = require("../constants/roles");
const { applicationStatusNotice } = require("../constants/statusCatalog");
const {
  hydrateApplicationsWithStudentProfiles,
} = require("../utils/hydrateApplications");
const { qualifyReferral } = require("../utils/studentWallet");
const { enqueueApplicationEmail } = require('../utils/applicationEmails');

const createApplication = asyncHandler(async (req, res) => {
  const { programId, documentIds = [], notes, applicantProfile } = req.body;

  if (!mongoose.isValidObjectId(programId) || !Array.isArray(documentIds) || documentIds.length > 30 ||
      documentIds.some((value) => typeof value !== 'string' || !mongoose.isValidObjectId(value)) ||
      new Set(documentIds).size !== documentIds.length) {
    return res.status(400).json({ message: 'Invalid program or document selection' });
  }
  const program = await Program.findById(programId).populate("university");
  if (!program) {
    res.status(404);
    throw new Error("Program not found");
  }

  const documents = await Document.find({
    _id: { $in: documentIds },
    student: req.user._id,
  });

  const existingApplication = await Application.findOne({
    student: req.user._id,
    program: program._id,
  });

  if (existingApplication) {
    res.status(400);
    throw new Error("An application for this program already exists");
  }

  if (documents.length !== documentIds.length) {
    return res.status(400).json({ message: 'One or more documents are unavailable' });
  }
  const requiredDocumentTypes = requiredDocumentTypesFor(program);
  const missing = missingDocumentTypes(requiredDocumentTypes, documents);
  if (missing.length) {
    return res.status(400).json({ message: 'Please upload the required documents', missingDocumentTypes: missing });
  }

  const application = await Application.create({
    student: req.user._id,
    program: program._id,
    university: program.university._id,
    documents: documents.map((document) => document._id),
    requiredDocumentTypes,
    applicantProfile,
    notes,
    status: "submitted",
    statusTimeline: [
      {
        status: "submitted",
        note: "Application submitted",
        changedBy: req.user._id,
      },
    ],
  });

  await Notification.create({
    user: req.user._id,
    title: "تم إرسال طلبك",
    message: `تم تقديم طلبك لبرنامج ${program.title} بنجاح. سيراجعه الفريق قريباً.`,
    type: "success",
    link: `/student/applications`,
  });

  if ((await Application.countDocuments({ student: req.user._id })) === 1) {
    await qualifyReferral(req.user._id).catch((error) => console.error("Referral qualification failed", error.message));
  }

  const populated = await Application.findById(application._id)
    .populate("student", "-password")
    .populate({
      path: "program",
      populate: { path: "university", populate: { path: "country" } },
    })
    .populate("documents")
    .populate("statusTimeline.changedBy", "name role");

  await enqueueApplicationEmail(populated, 'submitted');
  res.status(201).json(await hydrateApplicationsWithStudentProfiles(populated));
});

const getApplications = asyncHandler(async (req, res) => {
  const query = req.user.role === "student" ? { student: req.user._id } : {};

  const applications = await Application.find(query)
    .populate("student", "-password")
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

const getApplicationById = asyncHandler(async (req, res) => {
  const application = await Application.findById(req.params.id)
    .populate("student", "-password")
    .populate({
      path: "program",
      populate: {
        path: "university",
        populate: { path: "country" },
      },
    })
    .populate("documents")
    .populate("statusTimeline.changedBy", "name role");

  if (!application) {
    res.status(404);
    throw new Error("Application not found");
  }

  if (req.user.role === "student" && String(application.student._id) !== String(req.user._id)) {
    res.status(403);
    throw new Error("Forbidden");
  }

  res.json(await hydrateApplicationsWithStudentProfiles(application));
});

// Staff set either a website review status (`status`) or any of the detailed
// lifecycle statuses (`detailedStatus`); the model keeps both in sync.
const updateApplicationStatus = asyncHandler(async (req, res) => {
  const { status, detailedStatus, note } = req.body;
  const useDetailed = detailedStatus !== undefined;
  if (useDetailed ? !ALL_APPLICATION_DETAILED_STATUSES.includes(detailedStatus) : !ALL_APPLICATION_STATUSES.includes(status)) {
    return res.status(400).json({ message: "Invalid application status" });
  }
  if (note !== undefined && (typeof note !== "string" || note.length > 1000)) {
    return res.status(400).json({ message: "Invalid note" });
  }
  const application = await Application.findById(req.params.id).populate("program");

  if (!application) {
    res.status(404);
    throw new Error("Application not found");
  }

  if(req.body.version !== undefined && req.body.version !== application.__v){res.status(409);throw new Error('Application changed. Refresh and retry.');}
  application.$where={__v:application.__v};application.increment();
  if (useDetailed) application.detailedStatus = detailedStatus;
  else application.status = status;
  application.reviewedBy = req.user._id;
  application.statusTimeline.push({
    status: useDetailed ? detailedStatus : status,
    note,
    changedBy: req.user._id,
  });

  try{await application.save();}catch(error){if(['VersionError','DocumentNotFoundError'].includes(error.name)){res.status(409);throw new Error('Application changed. Refresh and retry.');}throw error;}

  // بند 115: auto-advance journeyStage based on new application status
  onApplicationStatusChange(application.student, useDetailed ? detailedStatus : status).catch(() => {});

  await Notification.create({
    user: application.student,
    ...applicationStatusNotice(application, application.program?.title),
    link: "/student/applications",
  });

  const populated = await Application.findById(application._id)
    .populate("student", "-password")
    .populate({
      path: "program",
      populate: { path: "university", populate: { path: "country" } },
    })
    .populate("documents")
    .populate("statusTimeline.changedBy", "name role");

  await enqueueApplicationEmail(populated, 'status');
  res.json(await hydrateApplicationsWithStudentProfiles(populated));
});

const deleteApplication = asyncHandler(async (req, res) => {
  const application = await Application.findById(req.params.id).populate("program");

  if (!application) {
    res.status(404);
    throw new Error("Application not found");
  }

  if(await require('../models/Invoice').exists({application:application._id})) {res.status(409);throw new Error('Application has financial history and cannot be deleted.');}
  await Application.deleteOne({ _id: application._id });

  await Notification.create({
    user: application.student,
    title: "تم حذف طلبك",
    message: `تم إزالة طلبك لبرنامج ${application.program?.title || "البرنامج المحدد"} من قِبل فريق القبول.`,
    type: "warning",
    link: "/student/applications",
  });

  res.json({ message: "Application deleted successfully", id: req.params.id });
});

module.exports = {
  createApplication,
  getApplications,
  getApplicationById,
  updateApplicationStatus,
  deleteApplication,
};
