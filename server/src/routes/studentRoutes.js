const express = require("express");
const {
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
  markAllStudentNotificationsRead,
  getStudentSupportTickets,
  createStudentSupportTicket,
  replyStudentSupportTicket,
  getStudentKnowledgeBase,
  getStudentFinancials,
  uploadPaymentProof,
  getArrivalServiceRequest,
  createArrivalServiceRequest,
  upsertArrivalServiceRequest,
  getStudentFavorites,
  toggleStudentFavorite,
  removeStudentFavorite,
  getOrientationTestResult,
  submitOrientationTest,
} = require("../controllers/studentController");
const { getMyRewards, getMyWallet, redeemWalletCredit } = require("../controllers/studentWalletController");
const { protect, authorize } = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const router = express.Router();

router.use(protect);
router.get("/profile", getProfile);
router.put("/profile", authorize("student", "partner"), updateProfile);
router.use(authorize("student"));
router.get('/insurance', require('../controllers/studentServicesController').mine('insurance'));
router.get('/equivalency', require('../controllers/studentServicesController').mine('equivalency'));
router.get("/agency-request", getAgencyRequest);
router.post("/agency-request", createAgencyRequest);
router.get("/overview", getDashboardOverview);
router.post("/documents", upload.single("file"), uploadDocument);
router.get("/documents", getDocuments);
router.post('/documents/lookup', require('../utils/asyncHandler')(async (req, res) => {
  const { fileHash, size, type, translationOf } = req.body;
  if (!/^[a-f0-9]{64}$/.test(fileHash || '') || !Number.isSafeInteger(size) || size <= 0 ||
      typeof type !== 'string' || !type.trim() || type.length > 100 ||
      (translationOf && !require('mongoose').isValidObjectId(translationOf))) {
    return res.status(400).json({ message: 'Invalid document lookup' });
  }
  const document = await require('../models/Document').findOne({
    student: req.user._id, type, fileHash, size, translationOf: translationOf || null, archivedAt: null, supersededBy: null,
  }).sort({ createdAt: -1 }).lean();
  res.json({ document: document ? { ...require('../models/Document').clientView(document), statusInfo: require('../constants/statusCatalog').documentStatusInfo(document) } : null });
}));
router.patch('/documents/:id/archive', require('../utils/asyncHandler')(async (req, res) => {
  if (!require('mongoose').isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Document not found' });
  const document = await require('../models/Document').findOneAndUpdate({ _id: req.params.id, student: req.user._id },
    { $set: { archivedAt: new Date() } }, { new: true }).lean();
  if (!document) return res.status(404).json({ message: 'Document not found' });
  res.json(require('../models/Document').clientView(document));
}));
router.get("/applications", getApplications);
router.get("/notifications", getStudentNotifications);
router.patch("/notifications/read-all", markAllStudentNotificationsRead);
router.patch("/notifications/:id/read", markStudentNotificationAsRead);
router.get("/support-tickets", getStudentSupportTickets);
router.post("/support-tickets", upload.single("file"), createStudentSupportTicket);
router.patch("/support-tickets/:id/reply", replyStudentSupportTicket);
router.get("/knowledge-base", getStudentKnowledgeBase);
router.get("/financials", getStudentFinancials);
router.post("/financials/invoices/:id/payment-proof", upload.single("file"), uploadPaymentProof);
router.get("/arrival-services", getArrivalServiceRequest);
router.post("/arrival-services", createArrivalServiceRequest);
router.put("/arrival-services", upsertArrivalServiceRequest);
router.put("/arrival-services/:id", upsertArrivalServiceRequest);
router.get("/favorites", getStudentFavorites);
router.post("/favorites/toggle", toggleStudentFavorite);
router.delete("/favorites/:id", removeStudentFavorite);
router.get("/orientation-test", getOrientationTestResult);
router.post("/orientation-test", submitOrientationTest);
router.get("/rewards", getMyRewards);
router.get('/listings', require('../controllers/studentListingsController').list());
router.get("/wallet", getMyWallet);
router.post("/wallet/redeem", redeemWalletCredit);

// #111-113: journey stage requirements (country/university/service rules)
router.get("/journey-requirements", require('../utils/asyncHandler')(async (req, res) => {
  const mongoose = require('mongoose');
  const StudentProfile = require('../models/StudentProfile');
  const Application = require('../models/Application');
  const Country = require('../models/Country');
  const University = require('../models/University');
  const OurService = require('../models/OurService');

  const profile = await StudentProfile.findOne({ user: req.user._id }).lean();
  const currentStage = profile?.journeyStage || 'file-received';

  // Find latest active application for country/university context
  const application = await Application.findOne({ student: req.user._id })
    .sort({ createdAt: -1 })
    .select('university')
    .populate('university', 'name country requiredDocuments')
    .lean();

  let countryRequirements = [];
  if (application?.university?.country) {
    const country = await Country.findById(application.university.country)
      .select('name journeyStageRequirements').lean();
    if (country) {
      const stageReqs = (country.journeyStageRequirements || []).find(r => r.stage === currentStage);
      countryRequirements = stageReqs?.documents || [];
    }
  }

  const universityDocuments = application?.university?.requiredDocuments || [];

  // Services linked to the current journey stage
  const linkedServices = await OurService.find({ journeyStage: currentStage, featured: true })
    .select('title priceDescription estimatedDuration price durationDays journeyStage').lean();

  res.json({
    currentStage,
    countryRequirements,
    universityDocuments,
    linkedServices,
  });
}));

module.exports = router;
