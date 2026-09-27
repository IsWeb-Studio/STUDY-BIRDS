// #35-43: Service request routes
const express = require('express');
const mongoose = require('mongoose');
const { protect, authorize } = require('../middleware/authMiddleware');
const { hasSection } = require('../middleware/employeeAccess');
const run = require('../utils/asyncHandler');
const ServiceRequest = require('../models/ServiceRequest');
const OurService = require('../models/OurService');
const { sendPushToUser } = require('../utils/pushNotifications');

const router = express.Router();
router.use(protect);

// ── Student endpoints ──────────────────────────────────────────────────────

// POST /api/service-requests — submit a new service request
router.post('/', authorize('student'), run(async (req, res) => {
  const { serviceId, notes = '' } = req.body;
  if (!mongoose.isValidObjectId(serviceId)) {
    return res.status(400).json({ message: 'معرّف الخدمة غير صالح' });
  }
  const service = await OurService.findById(serviceId).lean();
  if (!service) return res.status(404).json({ message: 'الخدمة غير موجودة' });

  const existing = await ServiceRequest.findOne({ student: req.user._id, service: serviceId, status: { $in: ['pending', 'assigned', 'in-progress'] } });
  if (existing) return res.status(409).json({ message: 'لديك طلب نشط لهذه الخدمة بالفعل', requestId: existing._id });

  const request = await ServiceRequest.create({
    student: req.user._id,
    service: serviceId,
    serviceTitle: service.title,
    notes: String(notes || '').trim().slice(0, 2000),
    statusHistory: [{ status: 'pending', changedBy: req.user._id, note: 'طلب جديد' }],
  });
  res.status(201).json(request);
}));

// GET /api/service-requests/mine — student's own requests
router.get('/mine', authorize('student'), run(async (req, res) => {
  const rows = await ServiceRequest.find({ student: req.user._id })
    .sort({ createdAt: -1 })
    .populate('service', 'title image')
    .populate('assignedTo', 'name')
    .lean();
  res.json(rows);
}));

// GET /api/service-requests/:id — get a single request (student owns it OR staff)
router.get('/:id', run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Not found' });
  const filter = { _id: req.params.id };
  if (req.user.role === 'student') filter.student = req.user._id;
  const req_ = await ServiceRequest.findOne(filter)
    .populate('service', 'title image detailBody')
    .populate('student', 'name email')
    .populate('assignedTo', 'name')
    .lean();
  if (!req_) return res.status(404).json({ message: 'الطلب غير موجود' });
  res.json(req_);
}));

// ── Admin / Employee endpoints ─────────────────────────────────────────────

const canManage = (req, res, next) => {
  if (req.user.role === 'admin') return next();
  if (req.user.role === 'employee' && (hasSection(req.user, 'services') || hasSection(req.user, 'support'))) return next();
  return res.status(403).json({ message: 'غير مصرح' });
};

// GET /api/service-requests — list all (admin/employee)
router.get('/', canManage, run(async (req, res) => {
  const filter = {};
  if (req.query.status) filter.status = req.query.status;
  const rows = await ServiceRequest.find(filter)
    .sort({ createdAt: -1 })
    .limit(200)
    .populate('student', 'name email')
    .populate('service', 'title')
    .populate('assignedTo', 'name')
    .lean();
  res.json(rows);
}));

// PATCH /api/service-requests/:id — update status / assign / staffNote
router.patch('/:id', canManage, run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Not found' });
  const { status, assignedTo, staffNote } = req.body;
  const { SERVICE_STATUSES } = require('../models/ServiceRequest');

  const existing = await ServiceRequest.findById(req.params.id).populate('student', 'name').lean();
  if (!existing) return res.status(404).json({ message: 'الطلب غير موجود' });

  const update = { $set: {} };
  if (status && SERVICE_STATUSES.includes(status)) {
    update.$set.status = status;
    update.$push = { statusHistory: { status, changedBy: req.user._id, note: staffNote || '' } };
  }
  if (assignedTo !== undefined) {
    update.$set.assignedTo = mongoose.isValidObjectId(assignedTo) ? assignedTo : null;
    if (!update.$push) update.$push = { statusHistory: { status: existing.status, changedBy: req.user._id, note: `تعيين لـ ${assignedTo}` } };
  }
  if (staffNote !== undefined) update.$set.staffNote = String(staffNote).trim().slice(0, 2000);

  const updated = await ServiceRequest.findByIdAndUpdate(existing._id, update, { new: true })
    .populate('service', 'title').populate('student', 'name email').populate('assignedTo', 'name').lean();

  // Push notification to student on status change
  if (status && status !== existing.status) {
    const statusLabels = { assigned: 'تم تعيين موظف لطلبك', 'in-progress': 'طلبك قيد التنفيذ', completed: 'تم إنجاز طلبك', cancelled: 'تم إلغاء طلبك' };
    const label = statusLabels[status];
    if (label) {
      sendPushToUser(existing.student._id, {
        title: `تحديث: ${existing.serviceTitle}`,
        body: label,
        link: '/student/services',
      }).catch(() => {});
    }
  }

  res.json(updated);
}));

module.exports = router;
