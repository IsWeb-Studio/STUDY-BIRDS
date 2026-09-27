const mongoose = require('mongoose');
const run = require('../utils/asyncHandler');
const User = require('../models/User');
const Insurance = require('../models/StudentInsurance');
const Equivalency = require('../models/StudentEquivalency');
const { hasSection } = require('../middleware/employeeAccess');

const config = {
  insurance: { model: Insurance, strings: ['provider', 'policyNumber', 'coverage', 'notes'],
    dates: ['startDate', 'endDate'], urls: ['cardFileUrl'], statuses: ['pending', 'active', 'expired'] },
  equivalency: { model: Equivalency, strings: ['authority', 'applicationNumber', 'notes', 'fees'],
    dates: ['submittedAt', 'expectedCompletionDate'], urls: ['resultFileUrl'],
    statuses: ['not-started', 'documents-collected', 'submitted', 'under-review', 'completed', 'rejected'] },
};
function publicRecord(row) {
  if (!row) return null;
  const { updatedBy, ...value } = row;
  if (value.status === 'active' && value.endDate && new Date(value.endDate) < new Date()) value.status = 'expired';
  return value;
}
const mine = kind => run(async (req, res) => res.json(publicRecord(await config[kind].model.findOne({ student: req.user._id }).lean())));
const staffRead = kind => run(async (req, res) => {
  if (!hasSection(req.user, 'services')) return res.status(403).json({ message: 'Forbidden' });
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Not found' });
  res.json(publicRecord(await config[kind].model.findOne({ student: req.params.id }).lean()));
});
const save = kind => run(async (req, res) => {
  if (!hasSection(req.user, 'services')) return res.status(403).json({ message: 'Forbidden' });
  if (!mongoose.isValidObjectId(req.params.id) || !await User.exists({ _id: req.params.id, role: 'student' })) return res.status(404).json({ message: 'Student not found' });
  const c = config[kind], body = req.body, patch = { updatedBy: req.user._id };
  const invalid = () => res.status(400).json({ message: 'تحقق من الحقول والتواريخ وروابط الملفات' });
  for (const key of c.strings) if (body[key] !== undefined) {
    if (typeof body[key] !== 'string' || body[key].length > 2000) return invalid();
    patch[key] = body[key].trim();
  }
  for (const key of c.dates) if (body[key] !== undefined) {
    if (body[key] !== null && (typeof body[key] !== 'string' || !Number.isFinite(Date.parse(body[key])))) return invalid();
    patch[key] = body[key] === null ? null : new Date(body[key]);
  }
  for (const key of c.urls) if (body[key] !== undefined) {
    if (typeof body[key] !== 'string' || body[key].length > 2000) return invalid();
    // Store protected application document paths or HTTPS links only.
    if (body[key] && !/^https:\/\/[^\s]+$/.test(body[key]) && !/^\/api\/documents\/[a-f\d]{24}\/access$/.test(body[key])) return invalid();
    patch[key] = body[key];
  }
  if (body.status !== undefined) {
    if (!c.statuses.includes(body.status)) return invalid();
    patch.status = body.status;
  }
  if (kind === 'equivalency' && body.requiredDocuments !== undefined) {
    if (!Array.isArray(body.requiredDocuments) || body.requiredDocuments.length > 40 || body.requiredDocuments.some(v => typeof v !== 'string' || v.length > 300)) return invalid();
    patch.requiredDocuments = body.requiredDocuments;
  }
  const current = await c.model.findOne({ student: req.params.id }).lean();
  const start = patch.startDate === undefined ? current?.startDate : patch.startDate;
  const end = patch.endDate === undefined ? current?.endDate : patch.endDate;
  if (start && end && end < start) return invalid();
  const row = await c.model.findOneAndUpdate({ student: req.params.id }, { $set: patch }, { upsert: true, new: true, runValidators: true }).lean();
  res.json(publicRecord(row));
});
module.exports = { mine, staffRead, save };
