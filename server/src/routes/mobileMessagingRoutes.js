const express = require('express');
const mongoose = require('mongoose');
const { protect } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const User = require('../models/User');
const ParentLink = require('../models/ParentLink');
const Application = require('../models/Application');
const Notification = require('../models/Notification');
const { Message } = require('../models/MobileWorkspace');
const sse = require('../utils/sseClients');
const ChatPreference = require('../models/ChatPreference');
const chatImages = require('../utils/chatImages');
const upload = require('../middleware/uploadMiddleware');
const { rateLimit } = require('express-rate-limit');
const router = express.Router();
router.use(protect);
const { membersFor, staffQuery } = require('../utils/studentSupportTeam');
const SupportTeam = require('../models/StudentSupportTeam');

async function contactFilter(user) {
  if (user.role === 'admin') {
    const students=await SupportTeam.distinct('student',{$or:[{members:user._id},{crmAdvisor:user._id}]});
    return {isActive:true,_id:{$ne:user._id},$or:[{role:{$ne:'student'}},{_id:{$in:students}}]};
  }
  const ids = [];
  if (user.role === 'parent') {
    const links = await ParentLink.find({ parent: user._id, status: 'approved' }).select('student').lean();
    ids.push(...links.map(link => link.student));
  }
  if (user.role === 'student') {
    ids.push(...(await membersFor(user._id)).map(member=>member._id));
    const links = await ParentLink.find({ student: user._id, status: 'approved' }).select('parent').lean();
    ids.push(...links.map(link => link.parent));
    const universities = await Application.distinct('university', { student: user._id });
    const accounts = await User.find({ role: 'university', linkedUniversity: { $in: universities }, isActive: true }).select('_id').lean();
    ids.push(...accounts.map(account => account._id));
  }
  if (user.role === 'university' && user.linkedUniversity) {
    ids.push(...await Application.distinct('student', { university: user.linkedUniversity }));
  }
  if(user.role==='employee'&&user.isActive!==false&&user.permissions?.includes('support'))ids.push(...await SupportTeam.distinct('student',{$or:[{members:user._id},{crmAdvisor:user._id}]}));
  return { isActive: true, _id: { $ne: user._id }, $or: [...(user.role === 'student' ? [{ role: 'student' }] : [{role:'admin'}]), { _id: { $in: ids } }] };
}
async function requireContact(user, recipient, res) {
  if (!mongoose.isValidObjectId(recipient)) { res.status(400); throw new Error('Invalid recipient'); }
  const target=await User.findOne({_id:recipient,isActive:true}).select('_id name role avatar');
  const student=user.role==='student'?user:(target?.role==='student'?target:null);
  const staff=user.role==='student'?target:user;
  if(student&&['admin','employee'].includes(staff?.role)){
    if((await membersFor(student._id)).some(member=>String(member._id)===String(staff._id)))return target;
    res.status(403);throw new Error('This support contact is not assigned to this student');
  }
  // These role combinations are already permitted by contactFilter; avoid
  // loading parent links and applications on every message/read/poll request.
  if (['admin', 'student'].includes(user.role)) {
    const direct = target;
    if (direct && String(direct._id) !== String(user._id) &&
        (user.role === 'admin' || ['student', 'admin'].includes(direct.role))) return direct;
  }
  const filter = await contactFilter(user);
  const contact = await User.findOne({ $and: [filter, { _id: recipient }] }).select('_id name role avatar');
  if (!contact) { res.status(403); throw new Error('This contact is unavailable'); }
  return contact;
}
router.get('/contacts', run(async (req, res) => {
  if(req.query.supportTeam==='true'){
    if(req.user.role!=='student')return res.status(403).json({message:'Students only'});
    const members=await membersFor(req.user._id);
    return res.set('Cache-Control','no-store').json(await User.find({...staffQuery,_id:{$in:members.map(m=>m._id)}}).select('_id name role avatar').sort({name:1}).lean());
  }
  res.json(await User.find(await contactFilter(req.user)).select('name role avatar').sort({ name: 1 }).limit(200).lean());
}));
router.get('/contacts/:id', run(async (req, res) => {
  res.set('Cache-Control', 'no-store').json(await requireContact(req.user, req.params.id, res));
}));
const fail = (statusCode, message) => { throw Object.assign(new Error(message), { statusCode }); };
const userId = value => new mongoose.Types.ObjectId(String(value));
const visible = user => ({ hiddenFor: { $ne: userId(user) } });
function present(message) {
  return { _id: message._id, sender: message.sender, recipient: message.recipient,
    body: message.deletedAt ? '' : message.body || '', createdAt: message.createdAt,
    readAt: message.readAt, deletedAt: message.deletedAt,
    imagePath: !message.deletedAt && message.image?.publicId ? `/mobile-workspace/messages/${message._id}/image` : null };
}
async function threadFilter(user, contact) {
  const pref = await ChatPreference.findOne({ user, contact }).lean();
  return { ...visible(user), ...(pref?.clearedAt ? { createdAt: { $gt: pref.clearedAt } } : {}),
    $or: [{ sender: user, recipient: contact }, { sender: contact, recipient: user }] };
}
async function permittedMessage(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) fail(400, 'Invalid message');
  const message = await Message.findOne({ _id: req.params.id, $or: [{ sender: req.user._id }, { recipient: req.user._id }] }).lean();
  if (!message) fail(404, 'Message unavailable');
  const peer = String(message.sender) === String(req.user._id) ? message.recipient : message.sender;
  await requireContact(req.user, peer, res);
  const filter = await threadFilter(req.user._id, peer);
  if (!await Message.exists({ ...filter, _id: message._id })) fail(404, 'Message unavailable');
  return { message, peer };
}
router.get('/conversations', run(async (req, res) => {
  if (req.user.role !== 'student') fail(403, 'Students only');
  let cursor;
  if (req.query.before) {
    const [date, id] = String(req.query.before).split('|');
    if (!mongoose.isValidObjectId(id) || !Number.isFinite(Date.parse(date))) fail(400, 'Invalid cursor');
    cursor = { date: new Date(date), id: userId(id) };
  }
  const prefs = await ChatPreference.find({ user: req.user._id }).select('contact muted clearedAt').lean();
  const byPeer = new Map(prefs.map(p => [String(p.contact), p]));
  const mutedIds = prefs.filter(p => p.muted).map(p => p.contact);
  const exclusions = prefs.filter(p => p.clearedAt).map(p => ({ $and: [
    { createdAt: { $lte: p.clearedAt } }, { $or: [{ sender: p.contact }, { recipient: p.contact }] },
  ] }));
  const match = { ...visible(req.user._id), ...(exclusions.length ? { $nor: exclusions } : {}),
    $or: [{ sender: req.user._id }, { recipient: req.user._id }] };
  const activeContact = [
    { $lookup: { from: User.collection.name, localField: '_id', foreignField: '_id',
      pipeline: [{ $match: { role: 'student', isActive: true } }, { $project: { name: 1, avatar: 1 } }], as: 'contact' } },
    { $unwind: '$contact' },
  ];
  if (req.query.summary === '1') {
    const totals = await Message.aggregate([
      { $match: { ...match, recipient: req.user._id, readAt: null, deletedAt: null, sender: { $nin: mutedIds } } },
      { $group: { _id: '$sender', count: { $sum: 1 } } }, ...activeContact,
      { $group: { _id: null, unreadTotal: { $sum: '$count' } } },
    ]);
    return res.set('Cache-Control', 'no-store').json({ unreadTotal: totals[0]?.unreadTotal || 0 });
  }
  const [result] = await Message.aggregate([
    { $match: match }, { $sort: { createdAt: -1, _id: -1 } },
    { $group: { _id: { $cond: [{ $eq: ['$sender', req.user._id] }, '$recipient', '$sender'] }, lastMessage: { $first: '$$ROOT' },
      unreadCount: { $sum: { $cond: [{ $and: [{ $eq: ['$recipient', req.user._id] }, { $eq: [{ $ifNull: ['$readAt', null] }, null] }, { $eq: [{ $ifNull: ['$deletedAt', null] }, null] }] }, 1, 0] } } } },
    ...activeContact,
    { $facet: {
      totals: [{ $group: { _id: null, unreadTotal: { $sum: { $cond: [{ $in: ['$_id', mutedIds] }, 0, '$unreadCount'] } } } }],
      page: [
        ...(cursor ? [{ $match: { $or: [{ 'lastMessage.createdAt': { $lt: cursor.date } }, { 'lastMessage.createdAt': cursor.date, 'lastMessage._id': { $lt: cursor.id } }] } }] : []),
        { $sort: { 'lastMessage.createdAt': -1, 'lastMessage._id': -1 } }, { $limit: 31 },
      ],
    } },
  ]);
  const rows = result?.page || [], page = rows.slice(0, 30), last = page.at(-1)?.lastMessage;
  res.set('Cache-Control', 'no-store').json({ unreadTotal: result?.totals[0]?.unreadTotal || 0,
    nextCursor: rows.length > 30 ? `${last.createdAt.toISOString()}|${last._id}` : null,
    conversations: page.map(row => ({ contact: row.contact, unreadCount: row.unreadCount,
      muted: !!byPeer.get(String(row._id))?.muted,
      lastMessage: { ...present(row.lastMessage), body: row.lastMessage.deletedAt ? '' : (row.lastMessage.body || '').slice(0, 160) } })) });
}));
router.get('/conversations/:contact', run(async (req, res) => {
  await requireContact(req.user, req.params.contact, res);
  const pref = await ChatPreference.findOne({ user: req.user._id, contact: req.params.contact }).lean();
  res.set('Cache-Control', 'no-store').json({ muted: !!pref?.muted });
}));
router.put('/conversations/:contact', run(async (req, res) => {
  await requireContact(req.user, req.params.contact, res);
  if (typeof req.body.muted !== 'boolean') fail(400, 'Invalid preference');
  const pref = await ChatPreference.findOneAndUpdate({ user: req.user._id, contact: req.params.contact }, { $set: { muted: req.body.muted } }, { upsert: true, new: true });
  res.json({ muted: pref.muted });
}));
router.delete('/conversations/:contact', run(async (req, res) => {
  const cutoff = new Date();
  await requireContact(req.user, req.params.contact, res);
  await ChatPreference.findOneAndUpdate({ user: req.user._id, contact: req.params.contact }, { $max: { clearedAt: cutoff } }, { upsert: true });
  sse.push(req.user._id, 'conversation-cleared', { contact: req.params.contact });
  res.json({ deleted: true });
}));
router.get('/messages', run(async (req, res) => {
  const recipient = req.query.recipient;
  await requireContact(req.user, recipient, res);
  const filter = await threadFilter(req.user._id, recipient);
  if (req.query.before) {
    if (!mongoose.isValidObjectId(req.query.before)) fail(400, 'Invalid cursor');
    filter._id = { $lt: req.query.before };
  }
  // Refresh loaded bubbles as well as recent ones so unsends and read receipts propagate.
  if (req.query.ids) {
    const ids = String(req.query.ids).split(',');
    if (ids.length > 100 || ids.some(id => !mongoose.isValidObjectId(id))) fail(400, 'Invalid messages');
    filter._id = { $in: ids };
  }
  const rows = await Message.find(filter).sort({ _id: -1 }).limit(req.query.ids ? 100 : 50).lean();
  res.set('Cache-Control', 'no-store').json(rows.reverse().map(present));
}));
async function saveMessage(req, res, image) {
  const body = req.body.body ?? '';
  if (typeof body !== 'string' || body.length > 4000 || (!body.trim() && !image)) fail(400, 'Message must contain text or an image');
  const [contact, recent] = await Promise.all([
    requireContact(req.user, req.body.recipient, res),
    Message.countDocuments({ sender: req.user._id, createdAt: { $gt: new Date(Date.now() - 60000) } }),
  ]);
  if (recent >= 30) fail(429, 'Too many messages. Please wait.');
  let message;
  try {
    message = await Message.create({ sender: req.user._id, recipient: contact._id, body: body.trim(), image,
      ...(image && req.body.operationId ? { operationId: req.body.operationId } : {}) });
  } catch (error) {
    if (error.code !== 11000 || !image || !req.body.operationId) throw error;
    const existing = await Message.findOne({ sender: req.user._id, recipient: contact._id, operationId: req.body.operationId }).lean();
    if (!existing) fail(409, 'Operation already used');
    return res.json(present(existing));
  }
  const data = present(message);
  sse.push(contact._id, 'message', data); sse.push(req.user._id, 'message', data);
  // Once saved, notification errors must never make a successful send appear to fail.
  try {
    const recipientPref = await ChatPreference.findOne({ user: contact._id, contact: req.user._id }).lean();
    if (!recipientPref?.muted) {
      await Notification.create({ user: contact._id, title: 'رسالة جديدة', message: `لديك رسالة من ${req.user.name}`, type: 'info', link: `/student/messages/${req.user._id}` });
    }
  } catch (error) { console.error('Message notification creation failed:', error.name); }
  res.status(201).json(data);
}
router.post('/messages', run((req, res) => saveMessage(req, res)));
router.post('/messages/image', rateLimit({ windowMs: 3600000, limit: 30, keyGenerator: req => String(req.user._id) }),
  upload.single('file'), run(async (req, res) => {
    await requireContact(req.user, req.body.recipient, res);
    if (!req.file || !['image/jpeg', 'image/png', 'image/webp'].includes(req.file.mimetype)) fail(415, 'Unsupported image');
    if (typeof (req.body.body ?? '') !== 'string' || (req.body.body || '').length > 4000) fail(400, 'Invalid caption');
    if (req.body.operationId) {
      if (typeof req.body.operationId !== 'string' || !/^[A-Za-z0-9_-]{8,100}$/.test(req.body.operationId)) fail(400, 'Invalid operation');
      const existing = await Message.findOne({ sender: req.user._id, operationId: req.body.operationId }).lean();
      if (existing) {
        if (String(existing.recipient) !== String(req.body.recipient)) fail(409, 'Operation already used');
        return res.json(present(existing));
      }
    }
    const recent = await Message.countDocuments({ sender: req.user._id, createdAt: { $gt: new Date(Date.now() - 60000) } });
    if (recent >= 30) fail(429, 'Too many messages. Please wait.');
    const image = await chatImages.uploadChatImage(req.file, req.user._id);
    await saveMessage(req, res, image);
  }));
router.get('/messages/:id/image', run(async (req, res) => {
  const { message } = await permittedMessage(req, res);
  if (message.deletedAt || !message.image?.publicId) fail(404, 'Image unavailable');
  const bytes = await chatImages.readChatImage(message.image);
  res.set({ 'Cache-Control': 'private, no-store', 'Content-Type': 'image/jpeg', 'X-Content-Type-Options': 'nosniff' }).send(bytes);
}));
router.delete('/messages/:id', run(async (req, res) => {
  const { message, peer } = await permittedMessage(req, res);
  if (req.query.scope === 'everyone') {
    if (String(message.sender) !== String(req.user._id)) fail(403, 'Only the sender can unsend');
    await Message.updateOne({ _id: message._id, sender: req.user._id }, { $set: { body: '', deletedAt: message.deletedAt || new Date() }, $unset: { image: 1 } });
    const data = present(await Message.findById(message._id).lean());
    sse.push(peer, 'message-updated', data); sse.push(req.user._id, 'message-updated', data);
  } else if (!req.query.scope || req.query.scope === 'me') {
    await Message.updateOne({ _id: message._id }, { $addToSet: { hiddenFor: req.user._id } });
    sse.push(req.user._id, 'message-hidden', { _id: message._id });
  } else fail(400, 'Invalid deletion scope');
  res.json({ deleted: true });
}));
router.post('/messages/read', run(async (req, res) => {
  await requireContact(req.user, req.body.sender, res);
  if (req.body.through && !mongoose.isValidObjectId(req.body.through)) fail(400, 'Invalid message');
  const filter = await threadFilter(req.user._id, req.body.sender);
  const readAt = new Date();
  const result = await Message.updateMany({ ...filter, sender: req.body.sender, recipient: req.user._id, readAt: null, deletedAt: null,
    ...(req.body.through ? { _id: { $lte: req.body.through } } : {}) }, { $set: { readAt } });
  if (result.modifiedCount) sse.push(req.body.sender, 'read', { contact: req.user._id, through: req.body.through || null, readAt });
  res.json({ read: true });
}));
// GET /api/messaging/events — SSE stream for real-time message delivery
router.get('/events', (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-store',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.flushHeaders();
  res.write(': connected\n\n');

  sse.register(req.user._id, res);

  // Heartbeat every 25 seconds to keep proxies from closing idle connections
  const heartbeat = setInterval(() => {
    try { res.write(': ping\n\n'); } catch { clearInterval(heartbeat); }
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    sse.unregister(req.user._id, res);
  });
});

module.exports = router;
module.exports.contactFilter = contactFilter;
