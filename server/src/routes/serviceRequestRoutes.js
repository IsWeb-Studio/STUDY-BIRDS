// #35-43: Service request routes
const express = require('express');
const mongoose = require('mongoose');
const { protect, authorize } = require('../middleware/authMiddleware');
const { hasSection } = require('../middleware/employeeAccess');
const run = require('../utils/asyncHandler');
const ServiceRequest = require('../models/ServiceRequest');
const OurService = require('../models/OurService');
const Invoice = require('../models/Invoice');
const Application = require('../models/Application');
const { sendPushToUser } = require('../utils/pushNotifications');
const { withLease } = require('../utils/leaseLock');

const router = express.Router();
router.use(protect);

const managesServices = user => user.role === 'admin' ||
  (user.role === 'employee' && (hasSection(user, 'services') || hasSection(user, 'support')));
const canManage = (req, res, next) => managesServices(req.user)
  ? next() : res.status(403).json({ message: 'غير مصرح' });
// Explicit student projection: internal notes and employee identities never leave staff routes.
const studentView = row => {
  const value = row.toObject ? row.toObject() : row;
  const { staffNote, statusHistory, ...visible } = value;
  return { ...visible, statusHistory: (statusHistory || []).map(h => ({ status: h.status, changedAt: h.changedAt })) };
};

async function autoCreateInvoice(request) {
  if (!request.price || request.price <= 0) return null;
  const ts = Date.now().toString(36).toUpperCase();
  const invoiceNumber = `SRV-${ts}`;
  try {
    const inv = await Invoice.create({
      student: request.student,
      invoiceNumber,
      description: `خدمة: ${request.serviceTitle}`,
      amount: request.price,
      category: 'service',
      currency: 'USD',
    });
    await ServiceRequest.findByIdAndUpdate(request._id, { $set: { invoice: inv._id } });
    sendPushToUser(request.student, {
      title: 'فاتورة جديدة',
      body: `صدرت فاتورة خدمة "${request.serviceTitle}" بقيمة $${request.price}`,
      link: '/student/payments',
    }).catch(() => {});
    return inv;
  } catch (err) {
    // duplicate invoice number is safe to ignore; log others
    if (err.code !== 11000) console.error('[serviceRequest] invoice create failed:', err.message);
    return null;
  }
}

// ── Student endpoints ──────────────────────────────────────────────────────

// POST /api/service-requests — submit a new service request
router.post('/', authorize('student'), run(async (req, res) => {
  const { serviceId, notes = '' } = req.body;
  if (!mongoose.isValidObjectId(serviceId)) {
    return res.status(400).json({ message: 'معرّف الخدمة غير صالح' });
  }
  const service = await OurService.findById(serviceId).lean();
  if (!service) return res.status(404).json({ message: 'الخدمة غير موجودة' });

  await withLease(`service-request:${req.user._id}:${serviceId}`, async () => {
  const existing = await ServiceRequest.findOne({ student: req.user._id, service: serviceId, status: { $in: ['pending', 'assigned', 'in-progress'] } });
  if (existing) return res.status(409).json({ message: 'لديك طلب نشط لهذه الخدمة بالفعل', requestId: existing._id });

  const request = await ServiceRequest.create({
    student: req.user._id,
    service: serviceId,
    serviceTitle: service.title,
    notes: String(notes || '').trim().slice(0, 2000),
    price: service.price || 0,
    durationDays: service.durationDays || 0,
    statusHistory: [{ status: 'pending', changedBy: req.user._id, note: 'طلب جديد' }],
  });
  res.status(201).json(studentView(request));
  });
}));

// GET /api/service-requests/mine — student's own requests
router.get('/mine', authorize('student'), run(async (req, res) => {
  const rows = await ServiceRequest.find({ student: req.user._id })
    .sort({ createdAt: -1 })
    .populate('service', 'title image')
    .populate('assignedTo', 'name')
    .lean();
  res.json(rows.map(studentView));
}));

// GET /api/service-requests/:id — get a single request (student owns it OR staff)
router.get('/:id', run(async (req, res) => {
  if (req.user.role !== 'student' && !managesServices(req.user)) return res.status(403).json({ message: 'غير مصرح' });
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Not found' });
  const filter = { _id: req.params.id };
  if (req.user.role === 'student') filter.student = req.user._id;
  const req_ = await ServiceRequest.findOne(filter)
    .populate('service', 'title image detailBody')
    .populate('student', 'name email')
    .populate('assignedTo', 'name')
    .lean();
  if (!req_) return res.status(404).json({ message: 'الطلب غير موجود' });
  res.json(req.user.role === 'student' ? studentView(req_) : req_);
}));

// POST /api/service-requests/:id/documents — attach a document URL to a request
// #36: student or staff can attach documents (HTTPS links only)
router.post('/:id/documents', run(async (req, res) => {
  if (req.user.role !== 'student' && !managesServices(req.user)) return res.status(403).json({ message: 'غير مصرح' });
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Not found' });
  const { fileName, filePath, mimeType, size } = req.body;
  if (typeof filePath !== 'string' || !/^https:\/\/[^\s]+$/.test(filePath)) return res.status(400).json({ message: 'رابط المستند غير صالح' });
  if (typeof fileName !== 'string' || !fileName.trim() || fileName.length > 250) return res.status(400).json({ message: 'اسم الملف مطلوب' });
  const filter = { _id: req.params.id };
  if (req.user.role === 'student') filter.student = req.user._id;
  const existing = await ServiceRequest.findOne(filter);
  if (!existing) return res.status(404).json({ message: 'الطلب غير موجود' });
  if ((existing.documents || []).length >= 20) return res.status(409).json({ message: 'وصل الطلب إلى الحد الأقصى من المستندات' });
  const doc = { fileName: fileName.trim(), filePath, mimeType: typeof mimeType === 'string' ? mimeType.trim() : '', size: Number(size) || 0, uploadedAt: new Date() };
  existing.documents.push(doc);
  await existing.save();
  res.status(201).json(studentView(existing));
}));

// ── Admin / Employee endpoints ─────────────────────────────────────────────

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
  if (status !== undefined && !SERVICE_STATUSES.includes(status)) return res.status(400).json({ message: 'حالة غير صالحة' });
  if (assignedTo !== undefined && assignedTo !== null) {
    if (!mongoose.isValidObjectId(assignedTo)) return res.status(400).json({ message: 'معرّف الموظف غير صالح' });
    const assignee = await require('../models/User').findById(assignedTo).lean();
    if (!assignee?.isActive || !managesServices(assignee)) return res.status(400).json({ message: 'اختر مسؤول خدمات مخوّلًا ونشطًا' });
  }

  const existing = await ServiceRequest.findById(req.params.id).populate('student', 'name').lean();
  if (!existing) return res.status(404).json({ message: 'الطلب غير موجود' });
  if (req.body.expectedVersion !== undefined && req.body.expectedVersion !== (existing.__v || 0)) {
    return res.status(409).json({ message: 'تغيّر الطلب بواسطة موظف آخر؛ حدّث القائمة قبل الحفظ' });
  }

  const update = { $set: {}, $inc: { __v: 1 } };
  if (status && SERVICE_STATUSES.includes(status)) {
    update.$set.status = status;
    update.$push = { statusHistory: { status, changedBy: req.user._id, note: staffNote || '' } };
  }
  if (assignedTo !== undefined) {
    update.$set.assignedTo = mongoose.isValidObjectId(assignedTo) ? assignedTo : null;
    if (!update.$push) update.$push = { statusHistory: { status: existing.status, changedBy: req.user._id, note: `تعيين لـ ${assignedTo}` } };
  }
  if (staffNote !== undefined) update.$set.staffNote = String(staffNote).trim().slice(0, 2000);

  const updated = await ServiceRequest.findOneAndUpdate({ _id: existing._id, __v: existing.__v || 0 }, update, { new: true, runValidators: true })
    .populate('service', 'title').populate('student', 'name email').populate('assignedTo', 'name').lean();
  if (!updated) return res.status(409).json({ message: 'تغيّر الطلب؛ حدّث القائمة قبل الحفظ' });

  // Push notification to student on status change
  if (status && status !== existing.status) {
    const statusLabels = { assigned: 'تم تعيين موظف لطلبك', 'in-progress': 'طلبك قيد التنفيذ', 'en-route': 'السائق في الطريق إليك', completed: 'تم إنجاز طلبك', cancelled: 'تم إلغاء طلبك' };
    const label = statusLabels[status];
    if (label) {
      sendPushToUser(existing.student._id, {
        title: `تحديث: ${existing.serviceTitle}`,
        body: label,
        link: '/student/services',
      }).catch(() => {});
    }
    // #35: auto-create invoice when service request is completed and has a price
    if (status === 'completed' && !existing.invoice) {
      autoCreateInvoice(updated).catch(() => {});
    }
    // #75/76: if service has a journeyStage, update postAdmission on student's application
    if (status === 'completed') {
      const svc = await OurService.findById(existing.service).lean().catch(() => null);
      const stage = svc?.journeyStage?.trim();
      if (stage) {
        Application.findOne({
          student: existing.student._id,
          status: { $nin: ['rejected', 'file-completed-rejected', 'file-completed-accepted'] },
          $or: [
            { detailedStatus: { $in: ['accepted', 'final-admission', 'visa-preparation'] } },
            { status: 'final-accepted' },
          ],
        }).sort({ createdAt: -1 }).then(app => {
          if (!app) return;
          const now4 = new Date();
          return Application.updateOne({ _id: app._id }, {
            $set: { [`postAdmission.${stage}.status`]: 'completed', [`postAdmission.${stage}.updatedAt`]: now4 }
          });
        }).catch(() => {});
      }
    }
  }

  res.json(updated);
}));

// PATCH /api/service-requests/:id/driver — update driver tracking details (staff only)
router.patch('/:id/driver', canManage, run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Not found' });
  const { name = '', phone = '', vehicleType = '', vehicleNumber = '', etaMinutes = null } = req.body;
  if (typeof name !== 'string' || name.length > 120) return res.status(400).json({ message: 'اسم السائق غير صالح' });
  if (typeof phone !== 'string' || phone.length > 30) return res.status(400).json({ message: 'رقم الهاتف غير صالح' });
  if (etaMinutes !== null && (!Number.isInteger(etaMinutes) || etaMinutes < 0)) return res.status(400).json({ message: 'وقت الوصول المتوقع غير صالح' });

  const updated = await ServiceRequest.findByIdAndUpdate(req.params.id, {
    $set: { driverDetails: { name: name.trim(), phone: phone.trim(), vehicleType: String(vehicleType).trim().slice(0, 60), vehicleNumber: String(vehicleNumber).trim().slice(0, 30), etaMinutes, updatedAt: new Date() } },
  }, { new: true }).lean();
  if (!updated) return res.status(404).json({ message: 'الطلب غير موجود' });

  // Notify student if driver is assigned
  if (name.trim()) {
    sendPushToUser(updated.student, {
      title: 'تفاصيل السائق',
      body: `السائق ${name.trim()}${etaMinutes ? ` — وصول تقريبي خلال ${etaMinutes} دقيقة` : ''}`,
      link: '/student/services',
    }).catch(() => {});
  }
  res.json(updated);
}));

module.exports = router;
