const mongoose = require('mongoose');
const asyncHandler = require('../utils/asyncHandler');
const Team = require('../models/StudentSupportTeam');
const User = require('../models/User');
const { membersFor, staffQuery } = require('../utils/studentSupportTeam');

exports.mine = asyncHandler(async (req, res) => res.set('Cache-Control', 'no-store').json(await membersFor(req.user._id)));
exports.saveAdvisor = asyncHandler(async (req, res) => {
  const id = req.body.advisorId;
  if (Object.keys(req.body).some(key => key !== 'advisorId') || (id !== null && (typeof id !== 'string' || !mongoose.isValidObjectId(id)))) return res.status(400).json({ message: 'Invalid advisor' });
  if (!mongoose.isValidObjectId(req.params.id) || !await User.exists({ _id: req.params.id, role: 'student' })) return res.status(404).json({ message: 'Student not found' });
  if (id && !await User.exists({ ...staffQuery, _id: id })) return res.status(400).json({ message: 'Choose an active linked advisor with support access' });
  await Team.findOneAndUpdate({ student: req.params.id }, { $set: { crmAdvisor: id, updatedBy: req.user._id } }, { upsert: true, runValidators: true });
  res.set('Cache-Control', 'no-store').json({ advisorId: id, members: await membersFor(req.params.id) });
});
exports.read = asyncHandler(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id) || !await User.exists({ _id: req.params.id, role: 'student' })) {
    return res.status(404).json({ message: 'Student not found' });
  }
  const members = await membersFor(req.params.id);
  const candidates = req.user.role === 'admin' ? await User.find(staffQuery).select('_id name employeeRole').sort({ name: 1 }).lean() : [];
  res.json({ members, candidates, canEdit: req.user.role === 'admin' });
});
exports.save = asyncHandler(async (req, res) => {
  const ids = req.body.memberIds;
  if (!Array.isArray(ids) || ids.length > 20 || ids.some(id => typeof id !== 'string' || !mongoose.isValidObjectId(id)) || new Set(ids).size !== ids.length) {
    return res.status(400).json({ message: 'Invalid team members' });
  }
  if (!mongoose.isValidObjectId(req.params.id) || !await User.exists({ _id: req.params.id, role: 'student' })) {
    return res.status(404).json({ message: 'Student not found' });
  }
  if (await User.countDocuments({ ...staffQuery, _id: { $in: ids } }) !== ids.length) {
    return res.status(400).json({ message: 'Choose active employees with support access' });
  }
  await Team.findOneAndUpdate({ student: req.params.id }, { $set: { members: ids, updatedBy: req.user._id } }, { upsert: true, runValidators: true });
  res.json({ members: await membersFor(req.params.id) });
});
