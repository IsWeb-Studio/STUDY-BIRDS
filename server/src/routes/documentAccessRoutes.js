const router = require('express').Router();
const mongoose = require('mongoose');
const { protect } = require('../middleware/authMiddleware');
const { hasSection } = require('../middleware/employeeAccess');
const asyncHandler = require('../utils/asyncHandler');
const Document = require('../models/Document');
const Application = require('../models/Application');
const ParentLink = require('../models/ParentLink');
const { documentDownloadLink } = require('../utils/privateDocumentStorage');

router.post('/:id/access', protect, asyncHandler(async (req, res) => {
  res.set({ 'Cache-Control': 'no-store', 'Pragma': 'no-cache', 'Referrer-Policy': 'no-referrer' });
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Document not found' });
  const document = await Document.findById(req.params.id).select('+storage').lean();
  if (!document) return res.status(404).json({ message: 'Document not found' });
  let allowed = String(document.student) === String(req.user._id) || hasSection(req.user, 'applications') || hasSection(req.user, 'student-documents');
  if(!allowed && hasSection(req.user,'services'))allowed=Boolean(await require('../models/ServiceRequest').exists({'documents._id':document._id}));
  if (!allowed && req.user.role === 'parent') allowed = Boolean(await ParentLink.exists({ parent: req.user._id, student: document.student, status: 'approved' }));
  if (!allowed && req.user.role === 'university' && req.user.linkedUniversity) {
    allowed = Boolean(await Application.exists({ university: req.user.linkedUniversity, student: document.student, documents: document._id }));
  }
  if (!allowed) return res.status(404).json({ message: 'Document not found' });
  if (!document.storage?.publicId || document.storage.deliveryType !== 'authenticated') {
    return res.status(409).json({ message: 'This legacy document has not been migrated to private storage' });
  }
  res.json(documentDownloadLink(document.storage));
}));
module.exports = router;
