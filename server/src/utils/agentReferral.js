const Profile = require('../models/StudentProfile');
const User = require('../models/User');

// A manually entered application code must identify exactly one active agent.
async function resolveAgentReferral(code) {
  const profiles = await Profile.find({referralCode:code}).select('user').lean();
  const agents = await User.find({_id:{$in:profiles.map(row=>row.user)},role:'partner',isActive:true}).select('_id name').limit(2).lean();
  return agents.length===1 ? agents[0] : null;
}
module.exports={resolveAgentReferral};
