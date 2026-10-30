const express = require('express');
const mongoose = require('mongoose');
const { rateLimit } = require('express-rate-limit');
const { protect } = require('../middleware/authMiddleware');
const { hasSection } = require('../middleware/employeeAccess');
const run = require('../utils/asyncHandler');
const Ticket = require('../models/SupportTicket');
const voice = require('../utils/voiceNotes');
const upload = require('../middleware/voiceUpload');
const router = express.Router(); router.use(protect);
const fail = (statusCode, message) => { throw Object.assign(new Error(message), { statusCode }); };
async function permitted(req) {
  if (!mongoose.isValidObjectId(req.params.id)) fail(400, 'Invalid ticket');
  const ticket = await Ticket.findById(req.params.id);
  if (!ticket) fail(404, 'Ticket unavailable');
  const owner = [ticket.user, ticket.agent].some(id => id && String(id) === String(req.user._id));
  if (!owner && !hasSection(req.user, 'support-tickets')) fail(403, 'Forbidden');
  return { ticket, staff: !owner };
}
router.post('/tickets/:id/replies', rateLimit({ windowMs: 3600000, limit: 60, keyGenerator: req => String(req.user._id) }), upload, run(async (req, res) => {
  const { ticket, staff } = await permitted(req);
  if (typeof req.body.operationId !== 'string' || !/^[A-Za-z0-9_-]{8,100}$/.test(req.body.operationId)) fail(400, 'Invalid operation');
  const operationId = `${req.user._id}:${req.body.operationId}`;
  if (ticket.replies.some(reply => reply.operationId === operationId)) return res.json(ticket);
  if (ticket.status === 'closed') fail(400, 'Cannot reply to a closed ticket');
  const audio = await voice.uploadVoice(req.file, req.user._id);
  const replyId = new mongoose.Types.ObjectId();
  try {
    const updated = await Ticket.findOneAndUpdate({ _id: ticket._id, status: { $ne: 'closed' }, 'replies.operationId': { $ne: operationId } }, {
      $push: { replies: { _id: replyId, user: req.user._id, fromRole: staff ? 'admin' : req.user.role === 'partner' ? 'partner' : 'student',
        message: '🎤', operationId, audioStorage: audio, audioDuration: audio.duration,
        audioPath: `/voice/tickets/${ticket._id}/replies/${replyId}/audio` } },
      $set: { status: staff ? 'answered' : 'open' }, $inc: { __v: 1 },
    }, { new: true, runValidators: true });
    if (updated) {
      try {
        const recipient = staff ? ticket.user || ticket.agent : ticket.assignedTo;
        if (recipient) await require('../models/Notification').create({
          user: recipient, title: 'رسالة صوتية على تذكرة الدعم',
          message: `وصلت رسالة صوتية على التذكرة: ${ticket.subject}`, type: 'info',
        });
      } catch (_) { console.warn('Ticket voice notification failed'); }
      return res.status(201).json(updated);
    }
    const fresh = await Ticket.findById(ticket._id);
    if (fresh?.replies.some(reply => reply.operationId === operationId)) return res.json(fresh);
    fail(409, 'Ticket changed. Please refresh.');
  } finally {
    try { if (!await Ticket.exists({ 'replies.audioStorage.publicId': audio.publicId })) await voice.removeVoice(audio); }
    catch (_) { console.warn('Ticket voice attachment cleanup needs retry'); }
  }
}));
router.get('/tickets/:id/replies/:replyId/audio', run(async (req, res) => {
  await permitted(req);
  if (!mongoose.isValidObjectId(req.params.replyId)) fail(400, 'Invalid reply');
  const ticket = await Ticket.findById(req.params.id).select('+replies.audioStorage');
  const reply = ticket?.replies.id(req.params.replyId);
  if (!reply?.audioStorage?.publicId) fail(404, 'Voice recording unavailable');
  voice.sendVoice(res, await voice.readVoice(reply.audioStorage));
}));
module.exports = router;
