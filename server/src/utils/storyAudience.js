const Friendship = require('../models/Friendship');
const User = require('../models/User');
const { isBlocked } = require('./userBlocks');
async function friendIds(user) {
  const rows = await Friendship.find({ status: 'accepted', $or: [{ requester: user }, { recipient: user }] }).select('requester recipient').lean();
  return rows.map(r => String(r.requester) === String(user) ? r.recipient : r.requester);
}
async function canReadStory(user, author, session = null) {
  if (await isBlocked(user, author)) return false;
  return !!await User.exists({ _id: author, role: { $in: ['student', 'parent', 'university', 'employee'] }, isActive: true }).session(session);
}
module.exports = { friendIds, canReadStory };
