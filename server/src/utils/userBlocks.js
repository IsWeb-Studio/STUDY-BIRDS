const Block = require('../models/UserBlock');
async function blockedIds(user) {
  const rows = await Block.find({ $or: [{ user }, { blocked: user }] }).lean();
  return rows.map(row => String(row.user) === String(user) ? row.blocked : row.user);
}
async function isBlocked(user, peer) {
  return Boolean(await Block.exists({ $or: [{ user, blocked: peer }, { user: peer, blocked: user }] }));
}
module.exports = { blockedIds, isBlocked };
