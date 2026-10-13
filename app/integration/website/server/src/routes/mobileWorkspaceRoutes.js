const express = require('express');
const mongoose = require('mongoose');
const { protect, authorize } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const User = require('../models/User');
const Application = require('../models/Application');
const Profile = require('../models/StudentProfile');
const Document = require('../models/Document');
const Invoice = require('../models/Invoice');
const Notification = require('../models/Notification');
const University = require('../models/University');
const { Access, Task, Message, Decision, Preferences, Credit } = require('../models/MobileWorkspace');
const ActivityLog = require('../models/ActivityLog');
const Content = require('../models/MobileContent');
const MobileSettings = require('../models/MobileSettings');
const Program = require('../models/Program');
const { randomBytes } = require('node:crypto');
const upload = require('../middleware/uploadMiddleware');
const { uploadFileToCloudinary } = require('../utils/uploadToCloudinary');
const router = express.Router();
const fail = (res, message, code = 400) => { res.status(code); throw new Error(message); };
const oid = (v, res) => { if (!mongoose.isValidObjectId(v)) fail(res, 'Invalid identifier'); return v; };
const text = (v, res, max = 4000) => { if (typeof v !== 'string' || !v.trim() || v.length > max) fail(res, 'Please complete the required fields'); return v.trim(); };
const mobileRoles = ['student', 'partner', 'parent', 'university', 'employee'];
router.use(protect);
router.get('/preferences', run(async (req, res) => {
  res.json(await Preferences.findOne({ user: req.user._id }).select('-referredBy').lean() || { notifications: true, language: 'ar' });
}));
router.put('/preferences', run(async (req, res) => {
  const clean = {};
  for (const key of ['guardianName', 'guardianPhone', 'emergencyName', 'emergencyPhone', 'budget', 'preferredLanguage']) {
    if (typeof req.body[key] === 'string' && req.body[key].length <= 200) clean[key] = req.body[key].trim();
  }
  if (typeof req.body.notifications === 'boolean') clean.notifications = req.body.notifications;
  if (['ar', 'en'].includes(req.body.language)) clean.language = req.body.language;
  res.json(await Preferences.findOneAndUpdate({ user: req.user._id }, { $set: clean }, { new: true, upsert: true, runValidators: true }));
}));
router.get('/activity', run(async (req, res) => {
  const [logs, applications] = await Promise.all([
    ActivityLog.find({ user: req.user._id }).select('action description createdAt').sort({ createdAt: -1 }).limit(100).lean(),
    req.user.role === 'student' ? Application.find({ student: req.user._id }).select('statusTimeline').lean() : [],
  ]);
  res.json([...logs.map(row => ({ title: row.action, description: row.description, date: row.createdAt })),
    ...applications.flatMap(row => row.statusTimeline.map(stage => ({ title: stage.status, description: stage.note, date: stage.changedAt })))].sort((a, b) => new Date(b.date) - new Date(a.date)));
}));
router.get('/calendar', run(async (req, res) => {
  const settings = await MobileSettings.findOne({ key: 'mobile' }).lean();
  const calendarEnabled = !settings?.config?.maintenance && settings?.config?.modules?.find(m => m.key === 'calendar')?.enabled !== false;
  const [events, invoices, tasks, applications] = await Promise.all([
    calendarEnabled ? Content.find({ section: 'calendar', published: true, date: { $ne: null } }).select('title date body').lean() : [],
    Invoice.find({ student: { $in: await studentIds(req.user) }, dueDate: { $ne: null }, status: { $ne: 'paid' } }).select('description dueDate').lean(),
    Task.find({ assignedTo: req.user._id, dueDate: { $ne: null }, status: { $ne: 'completed' } }).select('title dueDate').lean(),
    Application.find(await applicationFilter(req.user)).populate('program', 'title applicationDeadline').lean(),
  ]);
  res.json([...events.map(row => ({ title: row.title, date: row.date, description: row.body })),
    ...invoices.map(row => ({ title: row.description, date: row.dueDate, description: 'موعد سداد الفاتورة' })),
    ...tasks.map(row => ({ title: row.title, date: row.dueDate, description: 'موعد المهمة' })),
    ...applications.filter(row => row.program?.applicationDeadline).map(row => ({ title: row.program.title, date: row.program.applicationDeadline, description: 'الموعد النهائي للتقديم' }))
  ].sort((a, b) => new Date(a.date) - new Date(b.date)));
}));
router.get('/referral', authorize('student'), run(async (req, res) => {
  let pref = await Preferences.findOneAndUpdate({ user: req.user._id }, { $setOnInsert: { user: req.user._id } }, { new: true, upsert: true });
  if (!pref.referralCode) pref = await Preferences.findOneAndUpdate({ user: req.user._id, referralCode: { $exists: false } }, { $set: { referralCode: randomBytes(6).toString('hex').toUpperCase() } }, { new: true }) || await Preferences.findOne({ user: req.user._id });
  res.json({ code: pref.referralCode, referrals: await Preferences.countDocuments({ referredBy: req.user._id }), linked: !!pref.referredBy });
}));
router.post('/referral', authorize('student'), run(async (req, res) => {
  const owner = await Preferences.findOne({ referralCode: text(req.body.code, res, 30).toUpperCase(), user: { $ne: req.user._id } });
  if (!owner) fail(res, 'رمز الإحالة غير صحيح');
  await Preferences.updateOne({ user: req.user._id }, { $setOnInsert: { user: req.user._id } }, { upsert: true });
  const row = await Preferences.findOneAndUpdate({ user: req.user._id, referredBy: null }, { $set: { referredBy: owner.user } }, { new: true });
  if (!row) fail(res, 'تم ربط حسابك بإحالة مسبقاً', 409); res.status(201).json({ linked: true });
}));
router.get('/wallet', authorize('student'), run(async (req, res) => {
  const entries = await Credit.find({ user: req.user._id }).select('amount description createdAt').sort({ createdAt: -1 }).lean();
  res.json({ balance: entries.reduce((sum, row) => sum + row.amount, 0), currency: 'USD', entries });
}));
router.get('/program-finder', run(async (req, res) => {
  const filter = {};
  if (typeof req.query.degree === 'string' && req.query.degree) filter.degreeLevel = req.query.degree;
  if (req.query.budget) {
    const budget = Number(req.query.budget); if (!Number.isFinite(budget) || budget < 0) fail(res, 'Invalid budget'); filter.tuition = { $lte: budget };
  }
  const rows = await Program.find(filter).select('title degreeLevel tuition language duration summary coverImage university').populate('university', 'name country').sort({ tuition: 1 }).limit(100).lean();
  const language = String(req.query.language || '').trim().toLowerCase();
  res.json(language ? rows.filter(row => (row.language || '').toLowerCase().includes(language)) : rows);
}));
const access = async (user) => await Access.findOne({ user: user._id }).lean() || { students: [], manager: false };
async function studentIds(user) {
  if (user.role === 'student') return [user._id];
  if (['parent', 'employee'].includes(user.role)) return (await access(user)).students;
  return [];
}
async function applicationFilter(user) {
  if (user.role === 'university') return { university: (await access(user)).university || null };
  return { student: { $in: await studentIds(user) } };
}
async function scopedApplication(req, res) {
  const item = await Application.findOne({ _id: oid(req.params.id, res), ...await applicationFilter(req.user) });
  if (!item) fail(res, 'Application not found', 404);
  return item;
}
async function contacts(user) {
  if (user.role === 'admin') return User.find({ isActive: true, role: { $in: mobileRoles } }).select('name email role').lean();
  const links = await Access.find({ students: { $in: await studentIds(user) } }).lean();
  const ids = new Set(links.map(x => String(x.user)));
  for (const value of await studentIds(user)) ids.add(String(value));
  if (user.role === 'university') {
    for (const row of await Application.find(await applicationFilter(user)).select('student').lean()) ids.add(String(row.student));
  }
  if (user.role === 'student') {
    const unis = await Application.distinct('university', { student: user._id });
    for (const row of await Access.find({ university: { $in: unis } }).select('user').lean()) ids.add(String(row.user));
  }
  ids.delete(String(user._id));
  return User.find({ isActive: true, $or: [{ _id: { $in: [...ids] } }, { role: 'admin' }] }).select('name email role').lean();
}
router.get('/contacts', run(async (req, res) => res.json(await contacts(req.user))));
router.get('/messages', run(async (req, res) => {
  res.json(await Message.find({ $or: [{ sender: req.user._id }, { recipient: req.user._id }] }).populate('sender recipient', 'name role').sort({ createdAt: 1 }).limit(1000).lean());
}));
router.post('/messages', run(async (req, res) => {
  const recipient = oid(req.body.recipient, res);
  if (!(await contacts(req.user)).some(x => String(x._id) === String(recipient))) fail(res, 'Recipient is not in your team', 403);
  res.status(201).json(await Message.create({ sender: req.user._id, recipient, body: text(req.body.body, res) }));
}));
router.post('/messages/read', run(async (req, res) => {
  if (!Array.isArray(req.body.ids) || req.body.ids.length > 1000) fail(res, 'Invalid messages');
  req.body.ids.forEach(id => oid(id, res));
  await Message.updateMany({ _id: { $in: req.body.ids }, recipient: req.user._id, readAt: null }, { $set: { readAt: new Date() } });
  res.json({ read: true });
}));
router.patch('/messages/:id/read', run(async (req, res) => {
  const item = await Message.findOneAndUpdate({ _id: oid(req.params.id, res), recipient: req.user._id }, { $set: { readAt: new Date() } }, { new: true });
  if (!item) fail(res, 'Message not found', 404); res.json(item);
}));
router.get('/notifications', run(async (req, res) => res.json(await Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).lean())));
router.patch('/notifications/:id/read', run(async (req, res) => {
  const item = await Notification.findOneAndUpdate({ _id: oid(req.params.id, res), user: req.user._id }, { $set: { isRead: true } }, { new: true });
  if (!item) fail(res, 'Notification not found', 404); res.json(item);
}));
router.get('/profile', run(async (req, res) => res.json({ name: req.user.name, email: req.user.email, role: req.user.role, emailVerified: req.user.emailVerified })));
router.put('/profile', run(async (req, res) => {
  const user = await User.findByIdAndUpdate(req.user._id, { $set: { name: text(req.body.name, res, 120) } }, { new: true });
  res.json({ name: user.name, email: user.email, role: user.role });
}));
router.get('/students', authorize('parent', 'employee'), run(async (req, res) => {
  res.json(await User.find({ _id: { $in: await studentIds(req.user) }, role: 'student' }).select('name email avatar').lean());
}));
router.get('/students/:id', authorize('parent', 'employee'), run(async (req, res) => {
  oid(req.params.id, res);
  if (!(await studentIds(req.user)).some(id => String(id) === req.params.id)) fail(res, 'Student not found', 404);
  const [user, profile, applications, documents, invoices] = await Promise.all([
    User.findById(req.params.id).select('name email'), Profile.findOne({ user: req.params.id }),
    Application.find({ student: req.params.id }).populate('program', 'title').populate('university', 'name'),
    Document.find({ student: req.params.id }), Invoice.find({ student: req.params.id }),
  ]);
  res.json({ user, profile, applications, documents, invoices });
}));
router.get('/applications', authorize('parent', 'employee', 'university', 'student'), run(async (req, res) => {
  res.json(await Application.find(await applicationFilter(req.user)).populate('student', 'name email').populate('program', 'title').populate('university', 'name').sort({ createdAt: -1 }).lean());
}));
router.get('/applications/:id', authorize('parent', 'employee', 'university', 'student'), run(async (req, res) => {
  const item = await scopedApplication(req, res);
  await item.populate('student', 'name email'); await item.populate('program', 'title'); await item.populate('university', 'name');
  await item.populate('documents');
  res.json({ ...item.toObject(), decisions: await Decision.find({ application: item._id }).sort({ createdAt: -1 }).lean() });
}));
router.patch('/applications/:id/status', authorize('university'), run(async (req, res) => {
  const item = await scopedApplication(req, res);
  if (!['under-review', 'accepted', 'rejected'].includes(req.body.status)) fail(res, 'Invalid decision');
  const note = text(req.body.note, res);
  item.status = req.body.status; item.reviewedBy = req.user._id;
  item.statusTimeline.push({ status: item.status, note, changedBy: req.user._id }); await item.save();
  await Notification.create({ user: item.student, title: 'تحديث طلب الجامعة', message: note, type: 'info' });
  res.json(item);
}));
router.post('/applications/:id/document-request', authorize('university'), run(async (req, res) => {
  const item = await scopedApplication(req, res); const message = text(req.body.message, res);
  const decision = await Decision.create({ application: item._id, author: req.user._id, kind: 'document-request', message });
  await Notification.create({ user: item.student, title: 'طلب مستند إضافي', message, type: 'info' }); res.status(201).json(decision);
}));
router.post('/applications/:id/admission-letter', authorize('university'), upload.single('file'), run(async (req, res) => {
  const item = await scopedApplication(req, res);
  if (!req.file) fail(res, 'Select an admission letter');
  const file = await uploadFileToCloudinary(req.file, 'study-birds/admission-letters');
  res.status(201).json(await Decision.create({ application: item._id, author: req.user._id, kind: 'admission-letter', fileUrl: file.url, fileName: req.file.originalname }));
}));
router.get('/tasks', authorize('employee'), run(async (req, res) => res.json(await Task.find({ assignedTo: req.user._id }).populate('student', 'name').sort({ dueDate: 1, createdAt: -1 }).lean())));
router.patch('/tasks/:id', authorize('employee'), run(async (req, res) => {
  if (!['pending', 'in-progress', 'completed'].includes(req.body.status)) fail(res, 'Invalid task status');
  const item = await Task.findOneAndUpdate({ _id: oid(req.params.id, res), assignedTo: req.user._id }, { $set: { status: req.body.status } }, { new: true });
  if (!item) fail(res, 'Task not found', 404); res.json(item);
}));
router.get('/manager', authorize('employee'), run(async (req, res) => {
  if (!(await access(req.user)).manager) fail(res, 'Manager access is required', 403);
  const ids = await studentIds(req.user);
  // Manager metrics are restricted to students assigned by the administrator.
  res.json({ students: ids.length, applications: await Application.countDocuments({ student: { $in: ids } }), tasks: await Task.find({ student: { $in: ids } }).populate('assignedTo', 'name').lean() });
}));
router.get('/overview', authorize(...mobileRoles), run(async (req, res) => {
  const permission = await access(req.user);
  res.json({ name: req.user.name, role: req.user.role, manager: permission.manager,
    students: (await studentIds(req.user)).length,
    applications: await Application.countDocuments(await applicationFilter(req.user)),
    pendingTasks: await Task.countDocuments({ assignedTo: req.user._id, status: { $ne: 'completed' } }),
    unreadMessages: await Message.countDocuments({ recipient: req.user._id, readAt: null }),
  });
}));
router.use('/admin', authorize('admin'));
router.get('/admin/accounts', run(async (req, res) => res.json({
  users: await User.find().select('name email role isActive').sort({ createdAt: -1 }).lean(),
  access: await Access.find().lean(), universities: await University.find().select('name').lean(), tasks: await Task.find().populate('assignedTo student', 'name').sort({ createdAt: -1 }).lean(),
})));
router.post('/admin/accounts', run(async (req, res) => {
  if (!mobileRoles.includes(req.body.role)) fail(res, 'Invalid mobile account type');
  const email = text(req.body.email, res, 200).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail(res, 'Invalid email');
  const password = text(req.body.password, res, 200); if (password.length < 8) fail(res, 'Password must contain 8 characters');
  if (await User.exists({ email })) fail(res, 'Email already in use', 409);
  const user = await User.create({ name: text(req.body.name, res, 120), email, password, role: req.body.role });
  if (['student', 'partner'].includes(user.role)) await Profile.create({ user: user._id });
  res.status(201).json({ _id: user._id, name: user.name, email: user.email, role: user.role });
}));
router.put('/admin/accounts/:id/access', run(async (req, res) => {
  const user = await User.findById(oid(req.params.id, res));
  if (!user || !['parent', 'university', 'employee'].includes(user.role)) fail(res, 'Select a parent, employee or university account');
  const students = req.body.students;
  if (!Array.isArray(students) || students.length > 1000) fail(res, 'Invalid student assignments');
  students.forEach(id => oid(id, res));
  if (new Set(students).size !== students.length || await User.countDocuments({ _id: { $in: students }, role: 'student' }) !== students.length) fail(res, 'Select valid students');
  const university = req.body.university || null;
  if (user.role === 'university' && (!university || !await University.exists({ _id: oid(university, res) }))) fail(res, 'Select a university');
  res.json(await Access.findOneAndUpdate({ user: user._id }, { $set: {
    students: ['parent', 'employee'].includes(user.role) ? students : [],
    university: user.role === 'university' ? university : null,
    manager: user.role === 'employee' && req.body.manager === true,
  } }, { new: true, upsert: true, runValidators: true }));
}));
router.post('/admin/tasks', run(async (req, res) => {
  const assignedTo = oid(req.body.assignedTo, res);
  if (!await User.exists({ _id: assignedTo, role: 'employee' })) fail(res, 'Select an employee');
  const student = req.body.student || null;
  if (student && !(await Access.findOne({ user: assignedTo, students: oid(student, res) }))) fail(res, 'Assign this student to the employee first');
  if (req.body.dueDate && !Number.isFinite(Date.parse(req.body.dueDate))) fail(res, 'Invalid deadline');
  res.status(201).json(await Task.create({ title: text(req.body.title, res, 200), description: typeof req.body.description === 'string' ? req.body.description.slice(0, 4000) : '', assignedTo, student, dueDate: req.body.dueDate || null, priority: req.body.priority === 'urgent' ? 'urgent' : 'normal', createdBy: req.user._id }));
}));
router.get('/admin/credits', run(async (req, res) => res.json(await Credit.find().populate('user', 'name email').sort({ createdAt: -1 }).limit(500).lean())));
router.post('/admin/credits', run(async (req, res) => {
  const user = oid(req.body.user, res); const amount = Number(req.body.amount);
  if (!Number.isFinite(amount) || amount === 0 || Math.abs(amount) > 1000000) fail(res, 'Invalid amount');
  if (!await User.exists({ _id: user, role: 'student' })) fail(res, 'Select a student');
  res.status(201).json(await Credit.create({ user, amount, description: text(req.body.description, res, 500), createdBy: req.user._id }));
}));
module.exports = router;
