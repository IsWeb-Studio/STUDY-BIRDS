const Friendship = require('../models/Friendship');
const User = require('../models/User');
const COMMUNITY_ROLES = Object.freeze(['student', 'parent', 'university', 'employee', 'admin']);
const AUDIENCE_ROLE = Object.freeze({
  students: 'student',
  guardians: 'parent',
  universities: 'university',
  employees: 'employee',
});
const ADMIN_AUDIENCES = Object.freeze([
  'students', 'guardians', 'universities', 'employees', 'allEligible',
]);

function audienceForRole(role) {
  return Object.entries(AUDIENCE_ROLE).find(([, value]) => value === role)?.[0] || null;
}

function audienceFilter(user) {
  if (!user || !COMMUNITY_ROLES.includes(user.role)) return { _id: null };
  const target = audienceForRole(user.role);
  return { $or: [
    { audience: 'allEligible' },
    ...(target ? [{ audience: target }] : []),
    { audience: { $exists: false } },
    { author: user._id },
  ] };
}

function publicationAudienceFor(role, body) {
  if (!body || typeof body !== 'object' || !COMMUNITY_ROLES.includes(role)) return null;
  const isAdmin = role === 'admin';
  const allowedFields = new Set([
    'text', 'imageUrl', 'videoUrl', 'operationId',
    ...(isAdmin ? ['audience', 'notifyAudience'] : []),
  ]);
  if (Object.keys(body).some(key => !allowedFields.has(key))) return null;
  if (isAdmin && body.notifyAudience !== undefined && typeof body.notifyAudience !== 'boolean') return null;
  if (isAdmin) {
    if (body.audience === undefined) return 'students';
    return ADMIN_AUDIENCES.includes(body.audience) ? body.audience : null;
  }
  return 'allEligible';
}

async function friendIds(user) {
  const rows = await Friendship.find({ status: 'accepted', $or: [{ requester: user }, { recipient: user }] }).select('requester recipient').lean();
  return rows.map(r => String(r.requester) === String(user) ? r.recipient : r.requester);
}
async function canReadStory(viewer, story, session = null) {
  if (!viewer || !story || !COMMUNITY_ROLES.includes(viewer.role)) return false;
  const author = story.author?._id || story.author;
  if (!author) return false;
  const audience = story.audience || 'allEligible';
  const visible = String(viewer._id) === String(author) ||
      audience === 'allEligible' || audience === audienceForRole(viewer.role);
  if (!visible) return false;
  return !!await User.exists({ _id: author, role: { $in: COMMUNITY_ROLES }, isActive: true }).session(session);
}
module.exports = {
  COMMUNITY_ROLES,
  AUDIENCE_ROLE,
  ADMIN_AUDIENCES,
  audienceForRole,
  audienceFilter,
  publicationAudienceFor,
  friendIds,
  canReadStory,
};
