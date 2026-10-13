const mongoose = require('mongoose');
const id = (ref) => ({ type: mongoose.Schema.Types.ObjectId, ref });
const Access = mongoose.model('MobileAccess', new mongoose.Schema({
  user: { ...id('User'), unique: true, required: true },
  students: [id('User')], university: id('University'), manager: { type: Boolean, default: false },
}, { timestamps: true }));
const Task = mongoose.model('MobileTask', new mongoose.Schema({
  title: { type: String, required: true }, description: String,
  assignedTo: { ...id('User'), required: true }, student: id('User'),
  status: { type: String, enum: ['pending', 'in-progress', 'completed'], default: 'pending' },
  priority: { type: String, enum: ['normal', 'urgent'], default: 'normal' }, dueDate: Date,
  createdBy: id('User'),
}, { timestamps: true }));
const Message = mongoose.model('MobileMessage', new mongoose.Schema({
  sender: { ...id('User'), required: true, index: true }, recipient: { ...id('User'), required: true, index: true },
  body: { type: String, required: true, maxlength: 4000 }, readAt: Date,
}, { timestamps: true }));
const Decision = mongoose.model('MobileDecision', new mongoose.Schema({
  application: { ...id('Application'), required: true, index: true },
  author: { ...id('User'), required: true }, kind: { type: String, enum: ['document-request', 'admission-letter'], required: true },
  message: String, fileUrl: String, fileName: String,
}, { timestamps: true }));
const Preferences = mongoose.model('MobilePreferences', new mongoose.Schema({
  user: { ...id('User'), unique: true, required: true },
  notifications: { type: Boolean, default: true }, language: { type: String, enum: ['ar', 'en'], default: 'ar' },
  guardianName: String, guardianPhone: String, emergencyName: String, emergencyPhone: String,
  budget: String, preferredLanguage: String,
  referralCode: { type: String, unique: true, sparse: true }, referredBy: id('User'),
}, { timestamps: true }));
const Credit = mongoose.model('MobileCredit', new mongoose.Schema({
  user: { ...id('User'), required: true, index: true },
  amount: { type: Number, required: true }, description: { type: String, required: true },
  createdBy: id('User'),
}, { timestamps: true }));
const emailCodeSchema = new mongoose.Schema({
  user: { ...id('User'), required: true }, email: { type: String, required: true },
  purpose: { type: String, enum: ['verify', 'reset', 'login', 'security'], required: true },
  digest: String, attempts: { type: Number, default: 0 }, expiresAt: { type: Date, expires: 0 },
}, { timestamps: true });
emailCodeSchema.index({ user: 1, purpose: 1 }, { unique: true });
const EmailCode = mongoose.model('MobileEmailCode', emailCodeSchema);
const Session = mongoose.model('MobileSession', new mongoose.Schema({
  user: { ...id('User'), required: true, index: true }, digest: { type: String, unique: true, required: true },
  device: String, lastSeen: Date, revoked: { type: Boolean, default: false },
  expiresAt: { type: Date, expires: 0 },
}, { timestamps: true }));
module.exports = { Access, Task, Message, Decision, Preferences, Credit, EmailCode, Session };
