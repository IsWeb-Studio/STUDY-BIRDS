const User = require('../models/User');
const Notification = require('../models/Notification');
const { hasSection } = require('../middleware/employeeAccess');

// Delivery failure must not make a saved reply appear unsent.
async function notifySupport(ticket, { recipient, title, message }) {
  try {
    let users;
    if (recipient === 'owner') users = [ticket.user || ticket.agent].filter(Boolean);
    else {
      const staff = await User.find({ isActive: true, $or: [{ role: 'admin' }, { role: 'employee', permissions: 'support' }] }).select('_id role permissions').lean();
      const assigned = staff.find(user => String(user._id) === String(ticket.assignedTo) && hasSection(user, 'support'));
      users = (assigned ? [assigned] : staff).map(user => user._id);
    }
    const link = recipient === 'owner'
      ? `/${ticket.requesterRole === 'student' ? 'student/support' : 'partner/tickets'}#ticket-${ticket._id}`
      : `/admin/support-tickets#ticket-${ticket._id}`;
    await Promise.all(users.map(user => Notification.create({ user, title, message, type: 'info', link })));
  } catch (error) { console.error('Support notification failed:', error.name); }
}

module.exports = { notifySupport };
