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

router.use(protect);
router.post("/", authorize("student"), createApplication);
router.get("/", authorize("student", "admin"), getApplications);
router.get("/:id", authorize("student", "admin"), getApplicationById);
router.put("/:id/status", authorize("admin"), updateApplicationStatus);
router.delete("/:id", authorize("admin"), deleteApplication);

module.exports = router;
