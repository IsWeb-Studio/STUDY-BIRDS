const mongoose = require('mongoose');
const Application = require('../models/Application');
const asyncHandler = require('../utils/asyncHandler');
const { hasSection } = require('../middleware/employeeAccess');
const { VISA_STATES, isVisaCaseEligible, visaCaseView } = require('../utils/visaCase');
const { advanceTo } = require('../utils/journeyAutomation');

const listVisaCases = asyncHandler(async (req, res) => {
  const candidates = await Application.find({ status: { $nin: ['rejected', 'file-completed-rejected', 'file-completed-accepted'] } })
    .select('student program university status detailedStatus visaCase __v updatedAt')
    .populate('student', 'name')
    .populate('program', 'title')
    .populate('university', 'name')
    .sort({ updatedAt: -1 })
    .limit(500)
    .lean();
  const rows = candidates.filter(isVisaCaseEligible).map(app => ({
    applicationId: app._id,
    student: app.student ? { _id: app.student._id, name: app.student.name } : null,
    program: app.program?.title || '', university: app.university?.name || '',
    ...visaCaseView(app),
  }));
  res.json(rows);
});

const getVisaCase = asyncHandler(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Application not found' });
  if (req.user.role !== 'student' && !hasSection(req.user, 'visa')) return res.status(403).json({ message: 'Access denied' });
  const app = await Application.findOne({ _id: req.params.id, ...(req.user.role === 'student' ? { student: req.user._id } : {}) }).lean();
  if (!app) return res.status(404).json({ message: 'Application not found' });
  res.json(visaCaseView(app));
});

function validRequirements(value) {
  return Array.isArray(value) && value.length <= 30
    && value.every(r => r && typeof r.label === 'string' && r.label.trim() && r.label.length <= 200 && typeof r.done === 'boolean');
}

const updateVisaCase = asyncHandler(async (req, res) => {
  const { status, requirements = [], appointmentDate = null, appointmentLocation = '',
    insuranceProvider = '', insurancePolicyNumber = '', insuranceExpiresAt = null, notes = '', version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || !VISA_STATES.includes(status) || !Number.isInteger(version) || version < 0
    || !validRequirements(requirements) || typeof appointmentLocation !== 'string' || appointmentLocation.length > 250
    || typeof insuranceProvider !== 'string' || insuranceProvider.length > 150
    || typeof insurancePolicyNumber !== 'string' || insurancePolicyNumber.length > 100
    || typeof notes !== 'string' || notes.length > 2000) {
    return res.status(400).json({ message: 'Choose a valid visa status and check the requirements, appointment and insurance fields.' });
  }
  const appointment = appointmentDate === null ? null : typeof appointmentDate === 'string' ? new Date(appointmentDate) : new Date(NaN);
  if (appointment && !Number.isFinite(appointment.getTime())) return res.status(400).json({ message: 'Invalid appointment date' });
  const expiresAt = insuranceExpiresAt === null ? null : typeof insuranceExpiresAt === 'string' ? new Date(insuranceExpiresAt) : new Date(NaN);
  if (expiresAt && !Number.isFinite(expiresAt.getTime())) return res.status(400).json({ message: 'Invalid insurance expiry' });
  const app = await Application.findById(req.params.id).lean();
  if (!app) return res.status(404).json({ message: 'Application not found' });
  if (!isVisaCaseEligible(app)) return res.status(409).json({ message: 'An active final admission is required' });
  const now = new Date();
  const values = {
    status, requirements: requirements.map(r => ({ label: r.label.trim(), done: r.done })),
    appointment: { date: appointment, location: appointmentLocation.trim() },
    insurance: { provider: insuranceProvider.trim(), policyNumber: insurancePolicyNumber.trim(), expiresAt },
    notes: notes.trim(), updatedAt: now,
  };
  const updated = await Application.findOneAndUpdate({ _id: app._id, __v: version, status: app.status, detailedStatus: app.detailedStatus }, {
    $set: { visaCase: values }, $inc: { __v: 1 },
    $push: { visaCaseHistory: { fromStatus: app.visaCase?.status || 'not-started', status, changedBy: req.user._id, changedAt: now } },
  }, { new: true, runValidators: true }).lean();
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh and retry.' });
  // بند 115: visa approved → advance journeyStage to 'visa'
  if (status === 'approved') advanceTo(updated.student, 'visa').catch(() => {});
  res.json(visaCaseView(updated));
});

module.exports = { listVisaCases, getVisaCase, updateVisaCase };
