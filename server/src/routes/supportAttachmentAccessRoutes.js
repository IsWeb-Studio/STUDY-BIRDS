const router = require('express').Router();
const mongoose = require('mongoose');
const { protect } = require('../middleware/authMiddleware');
const { hasSection } = require('../middleware/employeeAccess');
const asyncHandler = require('../utils/asyncHandler');
const SupportTicket = require('../models/SupportTicket');
const { documentDownloadLink } = require('../utils/privateDocumentStorage');

router.post('/:id/access', protect, asyncHandler(async (req, res) => {
  res.set({ 'Cache-Control': 'no-store', 'Pragma': 'no-cache', 'Referrer-Policy': 'no-referrer' });
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Support attachment not found' });
  const ticket = await SupportTicket.findById(req.params.id).select('+attachmentStorage').lean();
  if (!ticket) return res.status(404).json({ message: 'Support attachment not found' });
  const allowed = String(ticket.user) === String(req.user._id) || await require('../utils/studentSupportTeam').canReadTicket(req.user, ticket);
  if (!allowed) return res.status(404).json({ message: 'Support attachment not found' });
  if (!ticket.attachmentStorage?.publicId || ticket.attachmentStorage.deliveryType !== 'authenticated') return res.status(409).json({ message: 'This legacy attachment has not been migrated to private storage' });
  res.json(documentDownloadLink(ticket.attachmentStorage));
}));
module.exports = router;
