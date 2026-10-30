const mongoose = require('mongoose');
const run = require('../utils/asyncHandler');
const User = require('../models/User');
const Team = require('../models/StudentSupportTeam');
const staffQuery = { isActive: true, $or: [{ role: 'admin' }, { role: 'employee', permissions: 'support' }] };
async function membersFor(student) {
  const team = await Team.findOne({ student }).lean();
  return team ? User.find({ ...staffQuery, _id: { $in: [...team.members, ...(team.crmAdvisor ? [team.crmAdvisor] : [])] } }).select('_id name employeeRole').lean() : [];
}
exports.membersFor = membersFor;
exports.saveAdvisor = run(async (req, res) => {
  const id = req.body.advisorId;
  if (Object.keys(req.body).some(key => key !== 'advisorId') || (id !== null && (typeof id !== 'string' || !mongoose.isValidObjectId(id)))) return res.status(400).json({ message: 'Invalid advisor' });
  if (!await studentExists(req, res)) return;
  if (id && !await User.exists({ ...staffQuery, _id: id })) return res.status(400).json({ message: 'Choose an active linked advisor with support access' });
  await Team.findOneAndUpdate({ student: req.params.id }, { $set: { crmAdvisor: id, updatedBy: req.user._id } }, { upsert: true, runValidators: true });
  res.set('Cache-Control', 'no-store').json({ advisorId: id, members: await membersFor(req.params.id) });
});
async function studentExists(req, res) {
  if (!mongoose.isValidObjectId(req.params.id) || !await User.exists({ _id: req.params.id, role: 'student' })) {
    res.status(404).json({ message: 'Student not found' }); return false;
  }
  return true;
}
exports.mine = run(async (req, res) => res.set('Cache-Control', 'no-store').json(await membersFor(req.user._id)));
exports.read = run(async (req, res) => {
  if (!await studentExists(req, res)) return;
  const team = await Team.findOne({ student: req.params.id }).lean();
  const members = await membersFor(req.params.id);
  const memberIds = (team?.members || []).map(String);
  res.set('Cache-Control', 'no-store').json({ members, memberIds,
    teamMembers: members.filter(member => memberIds.includes(String(member._id))),
    crmAdvisor: members.find(member => String(member._id) === String(team?.crmAdvisor)) || null,
    candidates: req.user.role === 'admin' ? await User.find(staffQuery).select('_id name employeeRole').sort({ name: 1 }).lean() : [], canEdit: req.user.role === 'admin' });
});
exports.save = run(async (req, res) => {
  const ids = req.body.memberIds;
  if (!Array.isArray(ids) || ids.length > 20 || ids.some(id => typeof id !== 'string' || !mongoose.isValidObjectId(id)) || new Set(ids).size !== ids.length) return res.status(400).json({ message: 'Invalid team members' });
  if (!await studentExists(req, res)) return;
  if (await User.countDocuments({ ...staffQuery, _id: { $in: ids } }) !== ids.length) return res.status(400).json({ message: 'Choose active employees with support access' });
  await Team.findOneAndUpdate({ student: req.params.id }, { $set: { members: ids, updatedBy: req.user._id } }, { upsert: true, runValidators: true });
  res.set('Cache-Control', 'no-store').json({ members: await membersFor(req.params.id) });
});
