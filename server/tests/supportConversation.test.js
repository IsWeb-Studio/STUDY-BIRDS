const { test, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const Ticket = require('../src/models/SupportTicket');
const User = require('../src/models/User');
const Notification = require('../src/models/Notification');
const { replyStudentSupportTicket, createStudentSupportTicket } = require('../src/controllers/studentController');
const { replySupportTicketAdmin, assignSupportTicketAdmin } = require('../src/controllers/adminAgentController');
const { supportActor } = require('../src/utils/supportActor');
const ticketId = 'a'.repeat(24), studentId = 'b'.repeat(24), staffId = 'c'.repeat(24);
let original, ticket, notices, writes;
beforeEach(() => {
  original = { find: User.find, userById: User.findById, notification: Notification.create, findById: Ticket.findById, update: Ticket.findOneAndUpdate, adminUpdate: Ticket.findByIdAndUpdate, create: Ticket.create };
  ticket = { _id: ticketId, user: studentId, requesterRole: 'student', subject: 'Documents', message: 'Help', status: 'answered', replies: [], assignedTo: staffId, save: async () => {} };
  notices = []; writes = [];
  User.find = () => ({ select: () => ({ lean: async () => [{ _id: staffId, role: 'employee', permissions: ['support'], isActive: true }] }) });
  User.findById = () => ({ lean: async () => ({ _id: staffId, role: 'employee', permissions: ['support'], isActive: true }) });
  Notification.create = async value => { notices.push(value); return value; };
  Ticket.findById = async () => ticket;
  Ticket.findOneAndUpdate = async (filter, update) => { writes.push({ filter, update }); return { ...ticket, status: update.$set.status }; };
  Ticket.findByIdAndUpdate = async (id, update) => { writes.push({ id, update }); return { ...ticket, status: update.$set.status }; };
  Ticket.create = async data => ({ ...ticket, ...data, toObject: () => ({ ...data }) });
});
afterEach(() => { User.find = original.find; User.findById = original.userById; Notification.create = original.notification; Ticket.findById = original.findById; Ticket.findOneAndUpdate = original.update; Ticket.findByIdAndUpdate = original.adminUpdate; Ticket.create = original.create; });
const response = () => ({ statusCode: 200, status(code) { this.statusCode = code; return this; }, json(value) { this.body = value; return this; } });
const request = (message = 'Follow up') => ({ params: { id: ticketId }, user: { _id: studentId, name: 'Student' }, body: { message } });
const next = error => { throw error; };

test('student can continue an answered ticket; append is atomic and the assigned staff receives a linked notification', async () => {
  const res = response(); await replyStudentSupportTicket(request(), res, next);
  assert.equal(res.body.status, 'open'); assert.equal(writes[0].filter.status.$ne, 'closed');
  assert.equal(writes[0].update.$push.replies.message, 'Follow up');
  assert.equal(writes[0].update.$inc.__v, 1); assert.equal(notices[0].user, staffId);
  assert.equal(notices[0].link, `/admin/support-tickets#ticket-${ticketId}`);
});
test('other students and closed tickets cannot accept replies', async () => {
  const req = request(); req.user._id = 'd'.repeat(24); const res = response();
  await replyStudentSupportTicket(req, res, next); assert.equal(res.statusCode, 403);
  ticket.status = 'closed'; const closed = response(); await replyStudentSupportTicket(request(), closed, next); assert.equal(closed.statusCode, 400); assert.equal(writes.length, 0);
});
test('a concurrent closure prevents append and notification', async () => {
  Ticket.findOneAndUpdate = async () => null; const res = response();
  await replyStudentSupportTicket(request(), res, next); assert.equal(res.statusCode, 409); assert.equal(notices.length, 0);
});
test('notification failure never reports a saved reply as failed', async () => {
  Notification.create = async () => { throw new Error('Unavailable'); };
  const res = response(); await replyStudentSupportTicket(request(), res, next); assert.equal(res.statusCode, 200); assert.equal(res.body.status, 'open');
});
test('admin reply retains the staff name and notifies the ticket owner with the correct page', async () => {
  const req = request(); req.user = { _id: staffId, name: 'Advisor' }; const res = response();
  await replySupportTicketAdmin(req, res, next); assert.equal(writes[0].update.$push.replies.displayName, 'Advisor'); assert.equal(notices[0].user, studentId); assert.equal(notices[0].link, `/student/support#ticket-${ticketId}`);
});
test('new student tickets and assignment notify support staff', async () => {
  const req = request(); req.body = { subject: 'Question', message: 'Help', category: 'documents' };
  await createStudentSupportTicket(req, response(), next); assert.equal(notices.length, 1);
  await assignSupportTicketAdmin({ ...req, body: { assignedTo: staffId } }, response(), next); assert.equal(notices.length, 2); assert.equal(notices[1].user, staffId);
});
test('CRM author signatures bind the staff, ticket, text, status and time', () => {
  const identity = { id: 'crm-employee', name: 'Advisor', companyId: 'one', issuedAt: 100000 };
  const body = JSON.stringify({ ticketId, message: 'Reply', status: 'answered', ...identity });
  const signed = { ...identity, signature: createHmac('sha256', 'test-secret').update(body).digest('hex') };
  assert.equal(supportActor(ticketId, 'Reply', 'answered', signed, 'test-secret', 100000).displayName, 'Advisor');
  for (const changed of [{ ...signed, name: 'Other' }, { ...signed, signature: 'é'.repeat(64) }]) assert.throws(() => supportActor(ticketId, 'Reply', 'answered', changed, 'test-secret', 100000));
  assert.throws(() => supportActor(ticketId, 'Altered', 'answered', signed, 'test-secret', 100000));
  assert.throws(() => supportActor(ticketId, 'Reply', 'answered', signed, 'test-secret', 900000));
});
