const router = require('express').Router();
const mongoose = require('mongoose');
const { protect } = require('../middleware/authMiddleware');
const { hasSection } = require('../middleware/employeeAccess');
const run = require('../utils/asyncHandler');
const VerificationDocument = require('../models/VerificationDocument');
const { documentDownloadLink } = require('../utils/privateDocumentStorage');

router.post('/:id/access', protect, run(async (req, res) => {
  res.set({ 'Cache-Control': 'no-store', Pragma: 'no-cache', 'Referrer-Policy': 'no-referrer' });
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Document not found' });
  const document = await VerificationDocument.findById(req.params.id).select('+storage').lean();
  if (!document || !(String(document.agent) === String(req.user._id) || hasSection(req.user, 'verification'))) {
    return res.status(404).json({ message: 'Document not found' });
  }
  if (!document.storage?.publicId || document.storage.deliveryType !== 'authenticated') {
    return res.status(409).json({ message: 'This document requires private storage migration' });
  }
  res.json(documentDownloadLink(document.storage));
}));
module.exports = router;
