// #62/109/110: Employee productivity KPI — service requests, support tickets, document reviews, application updates
const mongoose = require('mongoose');
const asyncHandler = require('../utils/asyncHandler');
const User = require('../models/User');
const ServiceRequest = require('../models/ServiceRequest');
const SupportTicket = require('../models/SupportTicket');

// Aggregate stats for all active employees (or a single one when :id is provided)
async function buildStats(userIds, sinceDate) {
  const since = sinceDate || new Date(0);

  const [srStats, ticketReplies, ticketAssigned] = await Promise.all([
    // Service requests completed by each assignee
    ServiceRequest.aggregate([
      { $match: { status: 'completed', assignedTo: { $in: userIds }, updatedAt: { $gte: since } } },
      { $group: { _id: '$assignedTo', serviceRequestsCompleted: { $sum: 1 } } },
    ]),
    // Support tickets where each user replied at least once (unique tickets)
    SupportTicket.aggregate([
      { $unwind: '$replies' },
      { $match: { 'replies.user': { $in: userIds }, 'replies.createdAt': { $gte: since } } },
      { $group: { _id: { user: '$replies.user', ticket: '$_id' } } },
      { $group: { _id: '$_id.user', supportReplies: { $sum: 1 } } },
    ]),
    // Support tickets assigned to each user
    SupportTicket.aggregate([
      { $match: { assignedTo: { $in: userIds }, updatedAt: { $gte: since } } },
      { $group: { _id: '$assignedTo', ticketsAssigned: { $sum: 1 } } },
    ]),
  ]);

  const map = {};
  for (const id of userIds) map[String(id)] = { serviceRequestsCompleted: 0, supportReplies: 0, ticketsAssigned: 0 };
  for (const r of srStats) map[String(r._id)] = { ...map[String(r._id)], serviceRequestsCompleted: r.serviceRequestsCompleted };
  for (const r of ticketReplies) map[String(r._id)] = { ...map[String(r._id)], supportReplies: r.supportReplies };
  for (const r of ticketAssigned) map[String(r._id)] = { ...map[String(r._id)], ticketsAssigned: r.ticketsAssigned };
  return map;
}

// GET /api/admin/employee-stats — all active employees
const getEmployeeStats = asyncHandler(async (req, res) => {
  const since = req.query.since ? new Date(req.query.since) : undefined;
  const employees = await User.find({
    isActive: { $ne: false },
    $or: [{ role: 'admin' }, { role: 'employee' }],
  }).select('name email role permissions').lean();

  const ids = employees.map(e => new mongoose.Types.ObjectId(e._id));
  const statsMap = await buildStats(ids, since);
  res.json(employees.map(e => ({ ...e, stats: statsMap[String(e._id)] || {} })));
});

// GET /api/admin/employee-stats/:id — single employee
const getEmployeeStatsById = asyncHandler(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Employee not found' });
  const employee = await User.findOne({
    _id: req.params.id,
    $or: [{ role: 'admin' }, { role: 'employee' }],
  }).select('name email role permissions').lean();
  if (!employee) return res.status(404).json({ message: 'Employee not found' });
  const since = req.query.since ? new Date(req.query.since) : undefined;
  const statsMap = await buildStats([new mongoose.Types.ObjectId(employee._id)], since);
  res.json({ ...employee, stats: statsMap[String(employee._id)] || {} });
});

module.exports = { getEmployeeStats, getEmployeeStatsById };
