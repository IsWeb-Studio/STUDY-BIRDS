const express = require("express");
const {
  getPrograms,
  getProgramById,
  createProgram,
  updateProgram,
  deleteProgram,
  uploadProgramCover,
} = require("../controllers/programController");
const { protect } = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");
const { cacheRoute } = require("../utils/responseCache");

const { requireSection } = require("../middleware/employeeAccess");
const router = express.Router();
const { withRevisionHeader } = require('../utils/catalogRevision');

router.get("/", cacheRoute(60_000), getPrograms);
router.post("/upload-cover", protect, requireSection("programs"), upload.single("file"), uploadProgramCover);
router.get("/:id", cacheRoute(60_000), getProgramById);
router.post("/", protect, requireSection("programs"), createProgram);
router.put("/:id", protect, requireSection("programs"), withRevisionHeader, updateProgram);
router.delete("/:id", protect, requireSection("programs"), withRevisionHeader, deleteProgram);

module.exports = router;
