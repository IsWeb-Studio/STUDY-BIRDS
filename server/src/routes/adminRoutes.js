const express = require("express");
const {
  getMyKpis,
  getOverview,
  getStats,
  getStudents,
  getAdminApplications,
  getUsers,
  updateUser,
  updateSectionAccountStatus,
  getCountriesAdmin,
  createCountry,
  uploadCountryHeroImage,
  updateCountry,
  deleteCountry,
  getSiteSettingsAdmin,
  updateSiteSettings,
  getTestimonialsAdmin,
  uploadTestimonialAvatar,
  getRecognitionsAdmin,
  getOurServicesAdmin,
  getOurStoryAdmin,
  getFaqsAdmin,
  getExhibitionArticlesAdmin,
  getUpcomingEventAdmin,
  getPastEventsAdmin,
  getEventRegistrationsAdmin,
  getAgencyRequestsAdmin,
  createTestimonial,
  createRecognition,
  createOurService,
  upsertOurStory,
  createFaq,
  createExhibitionArticle,
  upsertUpcomingEvent,
  createPastEvent,
  updateTestimonial,
  updateRecognition,
  updateOurService,
  updateFaq,
  updateExhibitionArticle,
  updatePastEvent,
  updateAgencyRequestStatus,
  deleteTestimonial,
  deleteRecognition,
  deleteOurService,
  deleteFaq,
  deleteExhibitionArticle,
  deletePastEvent,
  uploadRecognitionImage,
  uploadOurServiceImage,
  uploadOurStoryImage,
  uploadExhibitionImage,
  uploadUpcomingEventImage,
  uploadPastEventMedia,
} = require("../controllers/adminController");
const {
  getStudyFields,
  createStudyField,
  updateStudyField,
  deleteStudyField,
  uploadStudyFieldImage,
} = require("../controllers/studyFieldController");
const {
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
  replySupportTicketAdmin,
  assignSupportTicketAdmin,
  escalateSupportTicketAdmin,
  markTicketEmergency,
  getKnowledgeBaseAdmin,
  createKnowledgeBaseItemAdmin,
  updateKnowledgeBaseItemAdmin,
  deleteKnowledgeBaseItemAdmin,
} = require("../controllers/adminAgentController");
const {
  getStudentDetailsAdmin,
  getStudentDocumentsAdmin,
  reviewStudentDocumentAdmin,
  getStudentNotificationsAdmin,
  getStudentFinancialsAdmin,
  createStudentInvoiceAdmin,
  updateStudentInvoiceAdmin,
  reviewPaymentProofAdmin,
  getArrivalRequestsAdmin,
  updateArrivalRequestAdmin,
  syncArrivalStagesAdmin,
  getStudentFavoritesAdmin,
  getOrientationResultsAdmin,
  updateOrientationResultAdmin,
} = require("../controllers/adminStudentModulesController");
// NEW — parent link approvals, university accounts, employee sub-roles.
const {
  getParentLinksAdmin,
  updateParentLinkStatusAdmin,
  getUniversityAccountsAdmin,
  createUniversityAccountAdmin,
  updateUniversityAccountAdmin,
  getEmployeesAdmin,
  updateEmployeeRoleAdmin,
} = require("../controllers/adminRoleManagementController");
const {
  getAccommodationListingsAdmin, createAccommodationListing, updateAccommodationListing, deleteAccommodationListing,
  getAccommodationBookingsAdmin, updateAccommodationBookingStatus,
} = require("../controllers/accommodationController");
const { getWalletEntriesAdmin, createWalletAdjustmentAdmin } = require("../controllers/studentWalletController");
const {
  listPostsAdmin, getPostAdmin, listReportsAdmin, listModerationLogAdmin, moderatePost, moderateComment,
  listSuspensionsAdmin, suspendUser, liftSuspension, getSettingsAdmin, updateSettingsAdmin,
} = require("../controllers/communityController");
const { unifiedSearch } = require("../controllers/unifiedSearchController");
const { protect, authorize } = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const router = express.Router();
const { authorizeAdminSection } = require("../middleware/employeeAccess");

router.use(protect, authorizeAdminSection);
for (const kind of ['insurance', 'equivalency']) {
  const controller = require('../controllers/studentServicesController');
  router.get(`/students/:id/${kind}`, controller.staffRead(kind));
  router.put(`/students/:id/${kind}`, controller.save(kind));
}
// #PRD-Admin: Unified global search across all entities
router.get("/search", unifiedSearch);
router.get("/my-kpis", getMyKpis);
router.get("/overview", getOverview);
router.get("/stats", getStats);
router.get("/students", getStudents);
router.get("/users", getUsers);
router.patch("/users/:id", updateUser);
router.patch("/students/:id/status", updateSectionAccountStatus);
router.patch("/partners/:id/status", updateSectionAccountStatus);
router.get("/applications", getAdminApplications);
router.get("/accommodation-listings", getAccommodationListingsAdmin);
router.post("/accommodation-listings", createAccommodationListing);
router.put("/accommodation-listings/:id", updateAccommodationListing);
router.delete("/accommodation-listings/:id", deleteAccommodationListing);
router.get("/accommodation-bookings", getAccommodationBookingsAdmin);
router.patch("/accommodation-bookings/:id", updateAccommodationBookingStatus);
router.get("/countries", getCountriesAdmin);
router.post("/countries/upload-image", upload.single("file"), uploadCountryHeroImage);
router.post("/countries", createCountry);
router.put("/countries/:id", updateCountry);
router.delete("/countries/:id", deleteCountry);
router.get("/site-settings", getSiteSettingsAdmin);
router.put("/site-settings", updateSiteSettings);
router.get("/study-fields", getStudyFields);
router.post("/study-fields/upload-image", upload.single("file"), uploadStudyFieldImage);
router.post("/study-fields", createStudyField);
router.put("/study-fields/:id", updateStudyField);
router.delete("/study-fields/:id", deleteStudyField);
router.get("/testimonials", getTestimonialsAdmin);
router.post("/testimonials/upload-avatar", upload.single("file"), uploadTestimonialAvatar);
router.post("/testimonials", createTestimonial);
router.put("/testimonials/:id", updateTestimonial);
router.delete("/testimonials/:id", deleteTestimonial);
router.get("/recognitions", getRecognitionsAdmin);
router.post("/recognitions/upload-image", upload.single("file"), uploadRecognitionImage);
router.post("/recognitions", createRecognition);
router.put("/recognitions/:id", updateRecognition);
router.delete("/recognitions/:id", deleteRecognition);
router.get("/our-services", getOurServicesAdmin);
router.post("/our-services/upload-image", upload.single("file"), uploadOurServiceImage);
router.post("/our-services", createOurService);
router.put("/our-services/:id", updateOurService);
router.delete("/our-services/:id", deleteOurService);
router.get("/our-story", getOurStoryAdmin);
router.put("/our-story", upsertOurStory);
router.post("/our-story/upload-image", upload.single("file"), uploadOurStoryImage);
router.get("/faqs", getFaqsAdmin);
router.post("/faqs", createFaq);
router.put("/faqs/:id", updateFaq);
router.delete("/faqs/:id", deleteFaq);
router.get("/upcoming-event", getUpcomingEventAdmin);
router.put("/upcoming-event", upsertUpcomingEvent);
router.post("/upcoming-event/upload-image", upload.single("file"), uploadUpcomingEventImage);
router.get("/past-events", getPastEventsAdmin);
router.post("/past-events/upload-media", upload.single("file"), uploadPastEventMedia);
router.post("/past-events", createPastEvent);
router.put("/past-events/:id", updatePastEvent);
router.delete("/past-events/:id", deletePastEvent);
router.get("/event-registrations", getEventRegistrationsAdmin);
router.get("/agency-requests", getAgencyRequestsAdmin);
router.patch("/agency-requests/:id", updateAgencyRequestStatus);
router.get("/partners", getPartnersAdmin);
router.get("/partner-students", getAllPartnerStudentsAdmin);
router.get("/partners/:id/students", getPartnerStudentsAdmin);
router.patch("/partner-students/:studentId", updatePartnerStudentStatusAdmin);
router.get("/partners/:id", getPartnerDetailsAdmin);
router.get("/payout-requests", getPayoutRequestsAdmin);
router.patch("/payout-requests/:id", updatePayoutRequestStatusAdmin);
router.get("/marketing-assets", getMarketingAssetsAdmin);
router.post("/marketing-assets", upload.single("file"), createMarketingAssetAdmin);
router.put("/marketing-assets/:id", updateMarketingAssetAdmin);
router.delete("/marketing-assets/:id", deleteMarketingAssetAdmin);
router.get("/verification-documents", getVerificationQueueAdmin);
router.patch("/verification-documents/:id", reviewVerificationDocumentAdmin);
router.get("/support-tickets", getSupportTicketsAdmin);
router.patch("/support-tickets/:id/reply", replySupportTicketAdmin);
router.patch("/support-tickets/:id/assign", assignSupportTicketAdmin);
router.patch("/support-tickets/:id/escalate", escalateSupportTicketAdmin);
router.patch("/support-tickets/:id/emergency", markTicketEmergency);
router.get("/knowledge-base", getKnowledgeBaseAdmin);
router.post("/knowledge-base", createKnowledgeBaseItemAdmin);
router.put("/knowledge-base/:id", updateKnowledgeBaseItemAdmin);
router.delete("/knowledge-base/:id", deleteKnowledgeBaseItemAdmin);
router.get("/student-financials", getStudentFinancialsAdmin);
router.get("/students/:id", getStudentDetailsAdmin);
router.get("/student-documents", getStudentDocumentsAdmin);
router.patch("/student-documents/:id", reviewStudentDocumentAdmin);
router.get("/student-notifications", getStudentNotificationsAdmin);
router.post("/student-financials/invoices", createStudentInvoiceAdmin);
router.patch("/student-financials/invoices/:id", updateStudentInvoiceAdmin);
router.patch("/student-financials/payment-proofs/:id", reviewPaymentProofAdmin);
router.get("/student-financials/wallet-entries", getWalletEntriesAdmin);
const rewardRules = require('../controllers/studentRewardsController');
router.get('/student-financials/reward-rules', rewardRules.listRules);
const studentListings = require('../controllers/studentListingsController');
router.get('/community-posts/listings', studentListings.list(true));
router.post('/community-posts/listings', studentListings.save);
router.put('/community-posts/listings/:id', studentListings.save);
router.post('/student-financials/reward-rules', rewardRules.saveRule);
router.put('/student-financials/reward-rules/:id', rewardRules.saveRule);
router.post("/student-financials/wallet-entries", createWalletAdjustmentAdmin);
router.get("/community-posts", listPostsAdmin);
router.get("/community-posts/:id", getPostAdmin);
router.patch("/community-posts/:id", moderatePost);
router.patch("/community-comments/:id", moderateComment);
router.get("/community-reports", listReportsAdmin);
router.get("/community-moderation-log", listModerationLogAdmin);
router.get("/community-suspensions", listSuspensionsAdmin);
router.post("/community-suspensions", suspendUser);
router.delete("/community-suspensions/:userId", liftSuspension);
router.get("/community-settings", getSettingsAdmin);
router.put("/community-settings", updateSettingsAdmin);
router.get("/student-arrival-requests", getArrivalRequestsAdmin);
router.patch("/student-arrival-requests/:id", updateArrivalRequestAdmin);
router.post("/student-arrival-requests/sync-stages", syncArrivalStagesAdmin);
router.get("/student-favorites", getStudentFavoritesAdmin);
router.get("/student-orientation-results", getOrientationResultsAdmin);
router.patch("/student-orientation-results/:id", updateOrientationResultAdmin);
router.get("/exhibitions", getExhibitionArticlesAdmin);
router.post("/exhibitions/upload-image", upload.single("file"), uploadExhibitionImage);
router.post("/exhibitions", createExhibitionArticle);
router.put("/exhibitions/:id", updateExhibitionArticle);
router.delete("/exhibitions/:id", deleteExhibitionArticle);

// NEW — parent links, university accounts, employee sub-roles. Appended
// after every existing route; nothing above this line was changed.
router.get("/parent-links", getParentLinksAdmin);
router.patch("/parent-links/:id", updateParentLinkStatusAdmin);
router.get("/university-accounts", getUniversityAccountsAdmin);
router.post("/university-accounts", createUniversityAccountAdmin);
router.patch("/university-accounts/:id", updateUniversityAccountAdmin);
router.get("/employees", getEmployeesAdmin);
router.patch("/employees/:id/role", updateEmployeeRoleAdmin);

// #62/109/110: Employee productivity KPI
const { getEmployeeStats, getEmployeeStatsById } = require('../controllers/employeeStatsController');
router.get("/employee-stats", getEmployeeStats);
router.get("/employee-stats/:id", getEmployeeStatsById);

module.exports = router;
