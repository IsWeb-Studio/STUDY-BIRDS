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
router.get("/applications", getApplications);
router.get("/notifications", getStudentNotifications);
router.patch("/notifications/:id/read", markStudentNotificationAsRead);
router.get("/support-tickets", getStudentSupportTickets);
router.post("/support-tickets", upload.single("file"), createStudentSupportTicket);
router.get("/knowledge-base", getStudentKnowledgeBase);
router.get("/financials", getStudentFinancials);
router.post("/financials/invoices/:id/payment-proof", upload.single("file"), uploadPaymentProof);
router.get("/arrival-services", getArrivalServiceRequest);
router.put("/arrival-services", upsertArrivalServiceRequest);
router.get("/favorites", getStudentFavorites);
router.post("/favorites/toggle", toggleStudentFavorite);
router.delete("/favorites/:id", removeStudentFavorite);
router.get("/orientation-test", getOrientationTestResult);
router.post("/orientation-test", submitOrientationTest);
router.get("/rewards", getMyRewards);
router.get("/wallet", getMyWallet);
router.post("/wallet/redeem", redeemWalletCredit);

module.exports = router;
