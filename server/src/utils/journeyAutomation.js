/**
 * PRD بند 115: Journey Automation
 * Auto-advances a student's journeyStage when application/payment conditions are met.
 * Called after status changes — never called directly by the student.
 */
const StudentProfile = require('../models/StudentProfile');

const STAGE_ORDER = [
  'file-received',
  'documents-review',
  'university-selection',
  'applying',
  'university-review',
  'preliminary-accepted',
  'first-payment',
  'final-accepted',
  'visa',
  'travel',
  'reception',
  'accommodation',
  'university-registration',
  'studies-started',
];

function stageIndex(stage) {
  return STAGE_ORDER.indexOf(stage ?? 'file-received');
}

/**
 * Advance journeyStage to `targetStage` if the student is currently
 * behind it. Silently no-ops when already at or past the target.
 */
async function advanceTo(studentUserId, targetStage) {
  if (!studentUserId || !STAGE_ORDER.includes(targetStage)) return;
  const profile = await StudentProfile.findOne({ user: studentUserId });
  if (!profile) return;
  const current = stageIndex(profile.journeyStage);
  const target = stageIndex(targetStage);
  if (target > current) {
    profile.journeyStage = targetStage;
    await profile.save();
    // #53: trigger reward reconciliation on every journey stage advance
    try {
      const { reconcileRewards } = require('../controllers/studentRewardsController');
      reconcileRewards(studentUserId).catch(() => {});
    } catch {}
  }
}

/**
 * Called after an Application's `.status` changes.
 * Maps the new application status to the appropriate journey stage.
 */
async function onApplicationStatusChange(studentUserId, newStatus) {
  const mapping = {
    'submitted':            'applying',
    'under-review':         'university-review',
    'preliminary-accepted': 'preliminary-accepted',
    'accepted':             'final-accepted',
    'final-accepted':       'final-accepted',
  };
  const target = mapping[newStatus];
  if (target) await advanceTo(studentUserId, target);
}

/**
 * Called after a payment proof is approved.
 * Advances to first-payment stage (tuition received → university confirms enrollment).
 */
async function onPaymentApproved(studentUserId) {
  await advanceTo(studentUserId, 'first-payment');
}

module.exports = { advanceTo, onApplicationStatusChange, onPaymentApproved, STAGE_ORDER };
