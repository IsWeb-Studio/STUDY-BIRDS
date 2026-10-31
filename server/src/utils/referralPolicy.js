const Policy = require('../models/ReferralPolicy');
const legacyAmount = () => {
  const value = Number(process.env.STUDENT_REFERRAL_REWARD_AMOUNT ?? 15);
  if (!Number.isFinite(value) || value < 0 || value > 10000) throw new Error('Invalid referral reward configuration');
  return Math.round(value * 100) / 100;
};
async function resolveReferralReward(student) {
  const policies = await Policy.find({ scope: { $in: ['default', String(student)] } }).lean();
  const global = policies.find(row => row.scope === 'default');
  const selected = policies.find(row => row.scope === String(student)) || global;
  return global?.enabled === false || selected?.enabled === false ? 0 : selected?.amount ?? legacyAmount();
}
module.exports = { resolveReferralReward, legacyAmount };
