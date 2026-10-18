const User = require('../models/User');
const Notification = require('../models/Notification');
const { hasSection } = require('../middleware/employeeAccess');

// Delivery failure must not make a saved reply appear unsent.
async function notifySupport(ticket, { recipient, title, message }) {
  try {
    let users;
    if (recipient === 'owner') users = [ticket.user || ticket.agent].filter(Boolean);
    else {
      if (ticket.requesterRole === 'student' && !ticket.isEmergency) {
        const team = await require('./studentSupportTeam').membersFor(ticket.user);
        // An unassigned student's request still reaches administrators.
        users = team.length ? team.map(user => user._id) : (await User.find({ role: 'admin', isActive: true }).select('_id').lean()).map(user => user._id);
      } else {
      const staff = await User.find({ isActive: true, $or: [{ role: 'admin' }, { role: 'employee', permissions: 'support' }] }).select('_id role permissions').lean();
      const assigned = staff.find(user => String(user._id) === String(ticket.assignedTo) && hasSection(user, 'support'));
      users = (assigned ? [assigned] : staff).map(user => user._id);
      }
    }
    const link = recipient === 'owner'
      ? `/${ticket.requesterRole === 'student' ? 'student/support' : 'partner/tickets'}#ticket-${ticket._id}`
      : `/admin/support-tickets#ticket-${ticket._id}`;
    await Promise.all(users.map(user => Notification.create({ user, title, message, type: 'info', link })));
  } catch (error) { console.error('Support notification failed:', error.name); }
}

module.exports = { notifySupport };
