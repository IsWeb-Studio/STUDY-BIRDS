const mongoose = require('mongoose');
const run = require('../utils/asyncHandler');
const Rule = require('../models/StudentRewardRule');
const Entry = require('../models/StudentRewardEntry');
const Application = require('../models/Application');
const Referral = require('../models/StudentReferral');
const StudentProfile = require('../models/StudentProfile');

const JOURNEY_STAGE_ORDER = [
  'file-received', 'documents-review', 'university-selection', 'applying',
  'university-review', 'preliminary-accepted', 'first-payment', 'final-accepted',
  'visa', 'travel', 'reception', 'accommodation', 'university-registration', 'studies-started',
];

const JOURNEY_STAGE_TO_EVENT = {
  'documents-review':        'documents-submitted',
  'university-selection':    'university-selection',
  'first-payment':           'first-payment',
  'visa':                    'visa-approved',
  'studies-started':         'studies-started',
};

// Reconcile persisted server evidence, never client-supplied claims. Enabled
// rules apply to qualifying existing records as well as future ones.
async function reconcileRewards(student) {
  const rules = await Rule.find({ enabled: true }).lean();
  for (const rule of rules) {
    let sources;
    if (rule.event === 'referral-qualified') {
      sources = await Referral.find({ referrer: student, status: 'qualified' }).select('_id').lean();
    } else if (rule.event === 'final-admission') {
      const query = { student, $or: [
        { detailedStatus: 'final-admission' },
        { 'timeline.status': { $in: ['final-admission', 'final-accepted'] } },
      ]};
      sources = await Application.find(query).select('_id').lean();
    } else if (rule.event === 'application-submitted') {
      sources = await Application.find({ student }).select('_id').lean();
    } else if (Object.values(JOURNEY_STAGE_TO_EVENT).includes(rule.event)) {
      // For journey milestones, use the student profile as a single source
      const profile = await StudentProfile.findOne({ user: student }).select('_id journeyStage').lean();
      if (!profile) { sources = []; continue; }
      const stagesReached = Object.entries(JOURNEY_STAGE_TO_EVENT)
        .filter(([, evt]) => evt === rule.event)
        .map(([stage]) => stage);
      const currentIdx = JOURNEY_STAGE_ORDER.indexOf(profile.journeyStage);
      const reached = stagesReached.some(s => currentIdx >= JOURNEY_STAGE_ORDER.indexOf(s) && currentIdx >= 0);
      sources = reached ? [profile] : [];
    } else {
      sources = [];
    }
    for (const source of sources) {
      try {
        await Entry.updateOne({ student, event: rule.event, source: source._id }, {
          $setOnInsert: { points: rule.points, description: rule.title },
        }, { upsert: true, runValidators: true });
      } catch (error) { if (error.code !== 11000) throw error; }
    }
  }
}

// Loyalty tiers based on cumulative points
const LOYALTY_TIERS = [
  { name: 'platinum', minPoints: 5000 },
  { name: 'gold',     minPoints: 1500 },
  { name: 'silver',   minPoints: 500  },
  { name: 'bronze',   minPoints: 0    },
];
function loyaltyTier(points) {
  return LOYALTY_TIERS.find(t => points >= t.minPoints)?.name || 'bronze';
}

const getMyRewards = run(async (req, res) => {
  await reconcileRewards(req.user._id);
  const [totals, entries] = await Promise.all([
    Entry.aggregate([{ $match: { student: new mongoose.Types.ObjectId(req.user._id) } },
      { $group: { _id: null, total: { $sum: '$points' } } }]),
    Entry.find({ student: req.user._id }).sort({ createdAt: -1 }).limit(100).lean(),
  ]);
  const totalPoints = totals[0]?.total || 0;
  const tier = loyaltyTier(totalPoints);
  const nextTier = LOYALTY_TIERS.find(t => t.minPoints > totalPoints && t.minPoints > 0);
  res.json({
    totalPoints, tier,
    nextTier: nextTier ? { name: nextTier.name, pointsNeeded: nextTier.minPoints - totalPoints } : null,
    entries: entries.map(e => ({ ...e, type: e.event === 'referral-qualified' ? 'referral' : 'milestone' })),
  });
});

const listRules = run(async (_req, res) => res.json(await Rule.find().sort({ event: 1 }).lean()));
const saveRule = run(async (req, res) => {
  const { event, title, points, enabled } = req.body;
  const VALID_EVENTS = ['application-submitted', 'final-admission', 'referral-qualified',
    'documents-submitted', 'university-selection', 'first-payment', 'visa-approved', 'studies-started'];
  if (!VALID_EVENTS.includes(event) ||
      typeof title !== 'string' || !title.trim() || title.length > 150 ||
      !Number.isSafeInteger(points) || points < 1 || points > 1000000 || typeof enabled !== 'boolean') {
    return res.status(400).json({ message: 'تحقق من نوع الحدث والعنوان وعدد النقاط وحالة التفعيل' });
  }
  if (req.params.id && !mongoose.isValidObjectId(req.params.id)) return res.sendStatus(404);
  try {
    const value = { event, title: title.trim(), points, enabled };
    // Event identity is immutable, preserving the meaning of awarded entries.
    const rule = req.params.id
      ? await Rule.findOneAndUpdate({ _id: req.params.id, event }, { $set: value }, { new: true, runValidators: true })
      : await Rule.create(value);
    if (!rule) return res.status(409).json({ message: 'القاعدة غير موجودة أو تم تغيير نوع الحدث؛ حدّث القائمة' });
    res.status(req.params.id ? 200 : 201).json(rule);
  } catch (error) {
    if (error.code === 11000) return res.status(409).json({ message: 'توجد قاعدة لهذا الحدث بالفعل' });
    throw error;
  }
});
module.exports = { getMyRewards, listRules, saveRule, reconcileRewards };
