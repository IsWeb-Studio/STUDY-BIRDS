const Friendship = require('../models/Friendship');
const User = require('../models/User');
async function friendIds(user) {
  const rows = await Friendship.find({ status: 'accepted', $or: [{ requester: user }, { recipient: user }] }).select('requester recipient').lean();
  return rows.map(r => String(r.requester) === String(user) ? r.recipient : r.requester);
}
async function canReadStory(user, author, session = null) {
  return !!await User.exists({ _id: author, role: 'student', isActive: true }).session(session);
}
module.exports = { friendIds, canReadStory };
