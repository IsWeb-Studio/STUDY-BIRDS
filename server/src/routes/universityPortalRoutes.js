const express = require("express");
const {
  getApplications,
  getApplicationById,
  updateApplicationStatus,
  requestDocument,
  getFavoritesCount,
} = require("../controllers/universityPortalController");
const { protect, authorize } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(protect, authorize("university"));
router.get("/applications", getApplications);
router.get("/applications/:id", getApplicationById);
router.patch("/applications/:id/status", updateApplicationStatus);
router.post("/applications/:id/request-document", requestDocument);
router.get("/favorites-count", getFavoritesCount);

module.exports = router;
