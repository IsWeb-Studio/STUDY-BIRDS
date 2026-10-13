const mongoose = require('mongoose');
const Application = require('../models/Application');
const asyncHandler = require('../utils/asyncHandler');
const { hasSection } = require('../middleware/employeeAccess');
const { STAGES, STATES, isPostAdmissionEligible, postAdmissionStages } = require('../utils/postAdmissionJourney');
const view = app => ({ version: app.__v, eligible: isPostAdmissionEligible(app), stages: postAdmissionStages(app) });
const getPostAdmission = asyncHandler(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Application not found' });
  if (req.user.role !== 'student' && !hasSection(req.user, 'applications')) return res.status(403).json({ message: 'Access denied' });
  const app = await Application.findOne({ _id: req.params.id, ...(req.user.role === 'student' ? { student: req.user._id } : {}) }).lean();
  if (!app) return res.status(404).json({ message: 'Application not found' });
  res.json(view(app));
});
const updatePostAdmission = asyncHandler(async (req, res) => {
  const { stage, status, note, reference = '', dueAt = null, version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || !Object.hasOwn(STAGES, stage || '') || !STATES.includes(status)
    || !Number.isInteger(version) || version < 0 || typeof note !== 'string' || !note.trim() || note.length > 2000
    || typeof reference !== 'string' || reference.length > 250 || (status === 'completed' && !reference.trim())) {
    return res.status(400).json({ message: 'Choose a valid stage and status, add a student-facing note, and provide a reference for completion.' });
  }
  const due = dueAt === null ? null : typeof dueAt === 'string' ? new Date(dueAt) : new Date(NaN);
  if (due && !Number.isFinite(due.getTime())) return res.status(400).json({ message: 'Invalid deadline' });
  const app = await Application.findById(req.params.id).lean();
  if (!app) return res.status(404).json({ message: 'Application not found' });
  if (!isPostAdmissionEligible(app)) return res.status(409).json({ message: 'An active final admission is required' });
  const now = new Date();
  const values = { status, note: note.trim(), reference: reference.trim(), dueAt: due, updatedAt: now };
  const updated = await Application.findOneAndUpdate({ _id: app._id, __v: version, status: app.status, detailedStatus: app.detailedStatus }, {
    $set: { [`postAdmission.${stage}`]: values }, $inc: { __v: 1 },
    $push: { postAdmissionHistory: { stage, fromStatus: app.postAdmission?.[stage]?.status || 'not-started', ...values, changedBy: req.user._id, changedAt: now } },
  }, { new: true, runValidators: true }).lean();
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh and retry.' });
  res.json(view(updated));
});
module.exports = { getPostAdmission, updatePostAdmission };
