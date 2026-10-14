const mongoose = require('mongoose');
const Application = require('../models/Application');
const Document = require('../models/Document');
const asyncHandler = require('../utils/asyncHandler');
const { requiredDocumentTypesFor } = require('../utils/applicationRequirements');
const Notification = require('../models/Notification');
const { DOCUMENT_TYPES, documentLabel } = require('../constants/documentTypes');

const editableStates = new Set(['draft', 'documents-missing', 'ready-to-apply', 'submitted', 'under-review', 'additional-documents-required']);
const correctionStates = new Set(['missing', 'rejected', 'needs-revision', 'needs-translation', 'expired']);
const needsCorrection = doc => doc.status === 'rejected' || correctionStates.has(doc.detailedStatus);

// Replace one document type atomically, retaining the previous references for audit.
const attachApplicationDocument = asyncHandler(async (req, res) => {
  const { documentId, version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || typeof documentId !== 'string' ||
      !mongoose.isValidObjectId(documentId) || !Number.isInteger(version) || version < 0) {
    return res.status(400).json({ message: 'Invalid document selection or application version' });
  }
  const application = await Application.findOne({ _id: req.params.id, student: req.user._id })
    .populate('program').populate('documents').lean();
  if (!application) return res.status(404).json({ message: 'Application not found' });
  if (application.__v !== version) return res.status(409).json({ message: 'Application changed. Refresh before trying again.' });
  if (['accepted', 'rejected'].includes(application.status) || !editableStates.has(application.detailedStatus || application.status)) {
    return res.status(409).json({ message: 'Documents cannot be changed at this application stage. Contact your team.' });
  }
  const document = await Document.findOne({ _id: documentId, student: req.user._id }).lean();
  if (!document) return res.status(404).json({ message: 'Document not found' });
  if (needsCorrection(document) || document.supersededBy || document.archivedAt ||
      (document.expiresAt && new Date(document.expiresAt) <= new Date())) {
    return res.status(400).json({ message: 'Choose a valid current replacement document' });
  }
  const requested = (application.documentRequests || []).find(item => item.type === document.type && item.status === 'requested');
  const previous = application.documents.filter(doc => doc.type === document.type);
  const required = application.requiredDocumentTypes ?? requiredDocumentTypesFor(application.program);
  if (!previous.length && !required.includes(document.type) && !requested) {
    return res.status(400).json({ message: 'This document type is not requested for this application' });
  }
  if (previous.some(doc => String(doc._id) === documentId) || (!requested && previous.some(doc => !needsCorrection(doc)))) {
    return res.status(409).json({ message: 'This document is already attached or under review. Contact your team to change it.' });
  }
  const documentIds = application.documents.filter(doc => doc.type !== document.type).map(doc => doc._id);
  documentIds.push(document._id);
  const requestUpdates = requested ? { documentRequests: application.documentRequests.map(item => String(item._id) === String(requested._id) ? { ...item, status: 'submitted', document: document._id, submittedAt: new Date() } : item) } : {};
  const updated = await Application.findOneAndUpdate({
    _id: application._id, student: req.user._id, __v: version,
    status: application.status, detailedStatus: application.detailedStatus,
  }, {
    $set: { documents: documentIds, ...requestUpdates }, $inc: { __v: 1 },
    $push: { documentRevisions: { type: document.type, previousDocuments: previous.map(doc => doc._id), document: document._id, changedBy: req.user._id, changedAt: new Date() },
      statusTimeline: { status: application.detailedStatus || application.status, note: 'تم إرفاق مستند بديل أو استكمال مستند مطلوب؛ بانتظار مراجعة الفريق.', changedBy: req.user._id, changedAt: new Date() } },
  }, { new: true, runValidators: true }).populate('documents').populate({ path: 'program', populate: { path: 'university', populate: 'country' } });
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh before trying again.' });
  res.json(updated);
});

const requestApplicationDocument = asyncHandler(async (req, res) => {
  const { type, note, version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || !Object.hasOwn(DOCUMENT_TYPES, type || '') ||
      typeof note !== 'string' || !note.trim() || note.length > 2000 || !Number.isInteger(version) || version < 0) {
    return res.status(400).json({ message: 'Document type, note and version are required' });
  }
  const application = await Application.findById(req.params.id).lean();
  if (!application) return res.status(404).json({ message: 'Application not found' });
  if (['accepted', 'rejected'].includes(application.status) || !editableStates.has(application.detailedStatus || application.status) ||
      (application.documentRequests || []).some(item => item.type === type && ['requested', 'submitted'].includes(item.status))) {
    return res.status(409).json({ message: 'Application is closed or this document already has an open request' });
  }
  const updated = await Application.findOneAndUpdate({ _id: application._id, __v: version, status: application.status, detailedStatus: application.detailedStatus }, {
    $inc: { __v: 1 },
    $push: { documentRequests: { type, note: note.trim(), requestedBy: req.user._id, requestedAt: new Date() },
      statusTimeline: { status: application.detailedStatus || application.status, note: `طلب مستند إضافي: ${note.trim()}`, changedBy: req.user._id, changedAt: new Date() } },
  }, { new: true, runValidators: true }).populate('documents').populate('program');
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh first.' });
  // PRD 31: tell the student at once what is needed, why, and where to upload it.
  await Notification.create({
    user: application.student,
    title: `مطلوب منك: ${documentLabel(type)}`,
    message: `${updated.program?.title ? `${updated.program.title} — ` : ''}سبب الطلب: ${note.trim()}. ارفع المستند من صفحة الطلب، وسيراجعه الفريق فور وصوله.`,
    type: 'warning',
    link: '/student/applications',
  });
  res.status(201).json(updated);
});

const reviewApplicationDocumentRequest = asyncHandler(async (req, res) => {
  const { decision, note, version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || !mongoose.isValidObjectId(req.params.requestId) || !['approved', 'requested', 'cancelled'].includes(decision) ||
      typeof note !== 'string' || !note.trim() || note.length > 2000 || !Number.isInteger(version) || version < 0) return res.status(400).json({ message: 'Invalid review' });
  const application = await Application.findById(req.params.id).lean();
  if (!application) return res.status(404).json({ message: 'Application not found' });
  const request = (application.documentRequests || []).find(item => String(item._id) === req.params.requestId);
  if (!request) return res.status(404).json({ message: 'Document request not found' });
  if (['approved', 'cancelled'].includes(request.status) || (decision !== 'cancelled' && request.status !== 'submitted') ||
      ['accepted', 'rejected'].includes(application.status) || !editableStates.has(application.detailedStatus || application.status)) {
    return res.status(409).json({ message: 'Request cannot be reviewed in its current state' });
  }
  if (decision === 'approved') {
    const submittedDocument = request.document && await Document.findOne({ _id: request.document, student: application.student }).lean();
    if (!submittedDocument || needsCorrection(submittedDocument) || !application.documents.some(id => String(id) === String(request.document))) {
      return res.status(409).json({ message: 'The submitted document is unavailable or requires correction' });
    }
  }
  const reviewLabel = { approved: 'استيفاء طلب المستند', requested: 'طلب تصحيح المستند', cancelled: 'إلغاء طلب المستند' }[decision];
  const requests = application.documentRequests.map(item => String(item._id) === req.params.requestId ? { ...item, status: decision, note: note.trim(), reviewedBy: req.user._id, reviewedAt: new Date() } : item);
  const updated = await Application.findOneAndUpdate({ _id: application._id, __v: version, status: application.status, detailedStatus: application.detailedStatus }, {
    $inc: { __v: 1 }, $set: { documentRequests: requests },
    $push: { statusTimeline: { status: application.detailedStatus || application.status, note: `${reviewLabel}: ${note.trim()}`, changedBy: req.user._id, changedAt: new Date() } },
  }, { new: true, runValidators: true }).populate('documents').populate('program');
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh first.' });
  const label = documentLabel(request.type);
  const notice = {
    approved: [`تم اعتماد ${label}`, `استوفيت المستند المطلوب. ${note.trim()}`, 'success'],
    requested: [`${label} يحتاج تصحيحًا`, `السبب: ${note.trim()}. أعد رفعه من صفحة الطلب.`, 'warning'],
    cancelled: [`أُلغي طلب ${label}`, `لم يعد هذا المستند مطلوبًا. ${note.trim()}`, 'info'],
  }[decision];
  await Notification.create({ user: application.student, title: notice[0], message: notice[1], type: notice[2], link: '/student/applications' });
  res.json(updated);
});

module.exports = { attachApplicationDocument, requestApplicationDocument, reviewApplicationDocumentRequest };
