const express = require("express");
const {
  getApplications,
  getApplicationById,
  updateApplicationStatus,
  requestDocument,
  getFavoritesCount,
  uploadAvatar,
} = require("../controllers/universityPortalController");
const { protect, authorize } = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const router = express.Router();

router.use(protect, authorize("university"));
router.get("/applications", getApplications);
router.get("/applications/:id", getApplicationById);
router.patch("/applications/:id/status", updateApplicationStatus);
router.post("/applications/:id/request-document", requestDocument);
router.get("/favorites-count", getFavoritesCount);
router.post("/avatar", upload.single("file"), uploadAvatar);

module.exports = router;
