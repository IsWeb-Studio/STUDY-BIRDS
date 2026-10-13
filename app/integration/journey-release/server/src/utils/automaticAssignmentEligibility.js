const assignmentStageFilter = {
  status: { $in: ['submitted', 'under-review'] },
  detailedStatus: { $in: ['submitted', 'under-review', 'additional-documents-required'] },
};
const isAutomaticAssignmentStage = app => assignmentStageFilter.status.$in.includes(app.status)
  && assignmentStageFilter.detailedStatus.$in.includes(app.detailedStatus);
const canRequeueAssignment = app => isAutomaticAssignmentStage(app)
  && !app.assignedAdvisor && Boolean(app.assignmentHistory?.length) && !app.autoAssignmentEligible;
module.exports = { assignmentStageFilter, isAutomaticAssignmentStage, canRequeueAssignment };
