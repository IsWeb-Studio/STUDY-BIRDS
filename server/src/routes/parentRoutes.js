const express = require("express");
const {
  createLinkRequest,
  getLinkRequests,
  getChildren,
  getChildOverview,
  getChildPayments,
  uploadChildPaymentProof,
} = require("../controllers/parentController");
const { protect, authorize } = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const router = express.Router();

router.use(protect, authorize("parent"));
router.post("/link-requests", createLinkRequest);
router.get("/link-requests", getLinkRequests);
router.get("/children", getChildren);
router.get("/children/:studentId/overview", getChildOverview);
router.get("/children/:studentId/payments", getChildPayments);
router.post("/children/:studentId/invoices/:invoiceId/pay", upload.single("file"), uploadChildPaymentProof);

module.exports = router;
