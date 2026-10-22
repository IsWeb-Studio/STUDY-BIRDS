const Team = require('../models/StudentSupportTeam');
const User = require('../models/User');
const { hasSection } = require('../middleware/employeeAccess');
const staffQuery = { isActive: true, $or: [{ role: 'admin' }, { role: 'employee', permissions: 'support' }] };
async function membersFor(student) {
  const team = await Team.findOne({ student }).lean();
  if (!team) return [];
  return User.find({ ...staffQuery, _id: { $in: [...team.members, ...(team.crmAdvisor ? [team.crmAdvisor] : [])] } }).select('_id name employeeRole').lean();
}
async function ticketScope(user) {
  if (user.role === 'admin') return {};
  const teams = await Team.find({ $or: [{ members: user._id }, { crmAdvisor: user._id }] }).select('student').lean();
  return { $or: [{ isEmergency: true }, { requesterRole: { $ne: 'student' } }, { user: { $in: teams.map(team => team.student) } }] };
}
async function canReadTicket(user, ticket) {
  if (!hasSection(user, 'support')) return false;
  if (user.role === 'admin' || ticket.isEmergency || ticket.requesterRole !== 'student') return true;
  return Boolean(await Team.exists({ student: ticket.user, $or: [{ members: user._id }, { crmAdvisor: user._id }] }));
}
module.exports = { staffQuery, membersFor, ticketScope, canReadTicket };
