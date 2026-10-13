const mongoose = require('mongoose');
const Application = require('../models/Application');
const User = require('../models/User');
const asyncHandler = require('../utils/asyncHandler');
const { isAutomaticAssignmentStage, canRequeueAssignment } = require('../utils/automaticAssignmentEligibility');
const eligible = { isActive: { $ne: false }, $or: [{ role: 'admin' }, { role: 'employee', permissions: 'applications' }] };
const getAssignment = asyncHandler(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Application not found' });
  const application = await Application.findById(req.params.id).select('assignedAdvisor followUpDueAt __v autoAssignmentEligible assignmentHistory status detailedStatus').lean();
  if (!application) return res.status(404).json({ message: 'Application not found' });
  const advisors = await User.find(eligible).select('name').sort({ name: 1 }).lean();
  res.json({
    application: {
      assignedAdvisor: application.assignedAdvisor, followUpDueAt: application.followUpDueAt, __v: application.__v,
      autoAssignmentEligible: application.autoAssignmentEligible,
      hasAssignmentHistory: (application.assignmentHistory || []).length > 0,
      canRequeue: canRequeueAssignment(application),
      isQueuedForAutomaticAssignment: isAutomaticAssignmentStage(application) && !application.assignedAdvisor && application.autoAssignmentEligible === true,
    },
    advisors,
  });
});
const updateAssignment = asyncHandler(async (req, res) => {
  const { advisorId, dueAt, version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || !Number.isInteger(version) || version < 0 ||
      (advisorId !== null && (typeof advisorId !== 'string' || !mongoose.isValidObjectId(advisorId)))) return res.status(400).json({ message: 'Invalid assignment' });
  const due = dueAt === null ? null : typeof dueAt === 'string' ? new Date(dueAt) : new Date(NaN);
  if ((due && !Number.isFinite(due.getTime())) || (!advisorId && due)) return res.status(400).json({ message: 'Invalid follow-up deadline' });
  if (advisorId && !await User.exists({ _id: advisorId, ...eligible })) return res.status(400).json({ message: 'Choose an active admissions staff member' });
  const application = await Application.findById(req.params.id).lean();
  if (!application) return res.status(404).json({ message: 'Application not found' });
  if (['rejected', 'file-completed-rejected', 'file-completed-accepted'].includes(application.status) || ['rejected', 'completed'].includes(application.detailedStatus)) return res.status(409).json({ message: 'Closed application cannot be reassigned' });
  const updated = await Application.findOneAndUpdate({ _id: application._id, __v: version, status: application.status, detailedStatus: application.detailedStatus }, {
    $set: { assignedAdvisor: advisorId, followUpDueAt: due, autoAssignmentEligible: false }, $inc: { __v: 1 },
    $push: { assignmentHistory: { advisor: advisorId, dueAt: due, changedBy: req.user._id, changedAt: new Date() } },
  }, { new: true, runValidators: true }).select('assignedAdvisor followUpDueAt __v');
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh and try again.' });
  res.json(updated);
});
// Re-enters a manually cleared (unassigned, with history) application into the
// automatic scheduler's queue. Does not itself assign an advisor.
const requeueAssignment = asyncHandler(async (req, res) => {
  const { version } = req.body;
  if (!mongoose.isValidObjectId(req.params.id) || !Number.isInteger(version) || version < 0) return res.status(400).json({ message: 'Invalid request' });
  const application = await Application.findById(req.params.id).lean();
  if (!application) return res.status(404).json({ message: 'Application not found' });
  if (['rejected', 'file-completed-rejected', 'file-completed-accepted'].includes(application.status) || ['rejected', 'completed'].includes(application.detailedStatus)) return res.status(409).json({ message: 'Closed application cannot be reassigned' });
  if (application.assignedAdvisor) return res.status(409).json({ message: 'Application already has an advisor' });
  if (!application.assignmentHistory?.length) return res.status(409).json({ message: 'Application is already eligible for automatic assignment' });
  if (application.autoAssignmentEligible) return res.status(409).json({ message: 'Application is already queued for automatic assignment' });
  if (!isAutomaticAssignmentStage(application)) return res.status(409).json({ message: 'Only submitted admissions cases can enter the automatic assignment queue' });
  const updated = await Application.findOneAndUpdate({ _id: application._id, __v: version, assignedAdvisor: null,
    status: application.status, detailedStatus: application.detailedStatus, autoAssignmentEligible: { $ne: true }, 'assignmentHistory.0': { $exists: true } }, {
    $set: { autoAssignmentEligible: true },
    $inc: { __v: 1 },
    $push: { assignmentHistory: { advisor: null, changedBy: req.user._id, changedAt: new Date(), source: 'requeued' } },
  }, { new: true, runValidators: true }).select('assignedAdvisor followUpDueAt __v autoAssignmentEligible');
  if (!updated) return res.status(409).json({ message: 'Application changed. Refresh and try again.' });
  res.json(updated);
});
module.exports = { getAssignment, updateAssignment, requeueAssignment };
