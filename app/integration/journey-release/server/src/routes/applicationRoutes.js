const express = require("express");
const {
  createApplication,
  getApplications,
  getApplicationById,
  updateApplicationStatus,
  deleteApplication,
} = require("../controllers/applicationController");
const { protect, authorize } = require("../middleware/authMiddleware");

const router = express.Router();
const { requireSection, authorizeApplicationRead } = require("../middleware/employeeAccess");

const { attachApplicationDocument, requestApplicationDocument, reviewApplicationDocumentRequest } = require('../controllers/applicationDocumentController');
const { getAssignment, updateAssignment, requeueAssignment } = require('../controllers/applicationAssignmentController');
const { getPostAdmission, updatePostAdmission } = require('../controllers/postAdmissionController');
router.use(protect);
router.get('/:id/post-admission', getPostAdmission);
router.patch('/:id/post-admission', requireSection('applications'), updatePostAdmission);
router.use('/follow-up-reminders', require('./followUpReminderRoutes'));
router.get('/:id/assignment', requireSection('applications'), getAssignment);
router.patch('/:id/assignment', requireSection('applications'), updateAssignment);
router.post('/:id/assignment/requeue', requireSection('applications'), requeueAssignment);
router.post('/:id/document-requests', requireSection('applications'), requestApplicationDocument);
router.patch('/:id/document-requests/:requestId', requireSection('applications'), reviewApplicationDocumentRequest);
router.patch('/:id/documents', authorize('student'), attachApplicationDocument);
router.post("/", authorize("student"), createApplication);
router.get("/", authorizeApplicationRead, getApplications);
router.get("/:id", authorizeApplicationRead, getApplicationById);
router.put("/:id/status", requireSection("applications"), updateApplicationStatus);
router.delete("/:id", requireSection("applications"), deleteApplication);

module.exports = router;
