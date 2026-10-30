const fs = require('node:fs');
const path = require('node:path');
const mongoose = require('mongoose');
const Job = require('../models/AccountDeletionJob');
const User = require('../models/User');
const { cloudinary } = require('../config/cloudinary');

// Explicit ownership rules: never delete shared catalog or financial ledgers
// just because the departing user created/reviewed one of their records.
const owned = {
  StudentProfile: ['user'], Document: ['student'], Application: ['student'],
  ArrivalServiceRequest: ['student'], ServiceRequest: ['student'],
  AccommodationBooking: ['student'], AgencyRequest: ['student'],
  StudentInsurance: ['student'], StudentEquivalency: ['student'],
  OrientationTestResult: ['student'], FavoriteItem: ['student'],
  AlumniProfile: ['user'], ActivityLog: ['user'], Notification: ['user'],
  PushToken: ['user'], MobileSession: ['user'], MobileEmailCode: ['user'],
  IdentityCredential: ['user'], IdentityChallenge: ['user'],
  MobileAccess: ['user'], MobilePreferences: ['user'], MobileTask: ['student', 'assignedTo'],
  MobileMessage: ['sender', 'recipient'], ChatPreference: ['user', 'contact'],
  ParentLink: ['student', 'parent'], Friendship: ['requester', 'recipient'],
  CommunityPost: ['author'], CommunityComment: ['author'], CommunityReaction: ['user'],
  CommunityReport: ['reporter'], CommunitySuspension: ['user'],
  Story: ['author'], StoryStats: ['user'], StoryInteraction: ['user'], StoryVideo: ['owner'],
  SupportTicket: ['user', 'agent'], VerificationDocument: ['agent'],
  StudentSupportTeam: ['student'], StudentReferral: ['referrer', 'referredUser'],
  AgentStudent: ['agent'], ReferralEvent: ['agent'],
  ConsultationBooking: ['student'],
  UserBlock: ['user', 'blocked'], WinkRoom: ['state.players.id'],
  FinancialOutbox: ['user'], CrmSyncRecord: ['owner'], CrmSyncOperation: ['actor'],
};
const filterFor = (fields, user) => ({ $or: fields.map(field => ({ [field]: user })) });

function loadModels() {
  for (const file of fs.readdirSync(path.join(__dirname, '../models'))) {
    if (file.endsWith('.js')) require(path.join(__dirname, '../models', file));
  }
}

// Collect provider-owned file IDs before removing any records, so retries do
// not lose the information needed to erase files after a storage outage.
function findAssets(value, assets = [], owner) {
  if (!value || typeof value !== 'object') return assets;
  if (typeof value.publicId === 'string' && value.publicId) {
    assets.push({ publicId: value.publicId, resourceType: value.resourceType || 'image',
      deliveryType: value.deliveryType || 'upload' });
  }
  for (const child of Object.values(value)) {
    if (child && typeof child === 'object') findAssets(child, assets, owner);
    if (typeof child !== 'string' || !child.startsWith('https://res.cloudinary.com/')) continue;
    const match = child.match(/^https:\/\/res\.cloudinary\.com\/([^/]+)\/(image|video|raw)\/(upload|authenticated|private)\/(?:v\d+\/)?(.+)$/);
    if (!match || match[1] !== process.env.CLOUDINARY_CLOUD_NAME) continue;
    let publicId = decodeURIComponent(match[4]);
    // A user can paste another person's media URL into a story. Only delete
    // URL-only legacy assets from a folder demonstrably owned by this user.
    if (!publicId.split('/').includes(String(owner))) continue;
    if (match[2] !== 'raw') publicId = publicId.replace(/\.[^/.]+$/, '');
    assets.push({ publicId, resourceType: match[2], deliveryType: match[3] });
  }
  return assets;
}

function rowAssets(row, assets, owner) {
  // Only provider-issued structured file metadata is trusted. Never scan
  // arbitrary CRM values or user-authored JSON for a publicId to delete.
  findAssets({ storage: row.storage, attachmentStorage: row.attachmentStorage, image: row.image, audio: row.audio,
    avatar: row.avatar, filePath: row.filePath, legacyFilePath: row.legacyFilePath,
    imageUrl: row.imageUrl, videoUrl: row.videoUrl, url: row.url,
    resultFileUrl: row.resultFileUrl, cardFileUrl: row.cardFileUrl }, assets, owner);
  for (const file of [...(row.attachments || []), ...(row.documents || [])]) {
    findAssets({ filePath: file.filePath, storage: file.storage }, assets, owner);
  }
  for (const reply of row.replies || []) findAssets(reply.audioStorage, assets, owner);
}

async function finalizeDeletion(job) {
  await User.deleteOne({ _id: job.user });
  const mailer = require('./mailer');
  if (mailer.isMailerConfigured()) {
    await mailer.sendContactEmail({ to: job.email, subject: 'COVEY — Account deletion completed',
      text: 'Your COVEY account and associated personal content have been removed. Necessary accounting records may be retained with profile information removed. Contact studybirds.net/contact for questions about retained records.' });
  }
  await Job.deleteOne({ _id: job._id });
}

async function enqueueDeletion(user) {
  // Persist intent first; a crash between these writes is repaired by worker.
  const job = await Job.findOneAndUpdate({ user: user._id },
    { $setOnInsert: { email: user.email, state: 'pending' } }, { upsert: true, new: true });
  await User.updateOne({ _id: user._id }, { $set: { isActive: false }, $inc: { tokenVersion: 1 } });
  return job;
}

async function processDeletion(job) {
  if (job.state === 'complete') return finalizeDeletion(job);
  loadModels();
  const id = job.user;
  await User.updateOne({ _id: id }, { $set: { isActive: false } });
  if (!job.snapshot) {
    const posts = await mongoose.model('CommunityPost').find({ author: id }).select('_id').lean();
    const stories = await mongoose.model('Story').find({ author: id }).select('_id').lean();
    const assets = [];
    const user = await User.findById(id).lean();
    if (user) rowAssets(user, assets, id);
    for (const [name, fields] of Object.entries(owned)) {
      const model = mongoose.models[name];
      if (!model) continue;
    const rows = await model.find(filterFor(fields, id)).select('+storage +attachmentStorage +legacyFilePath +replies.audioStorage +image').lean();
      rows.forEach(row => rowAssets(row, assets, id));
    }
    const sharedTickets = await mongoose.model('SupportTicket').find({ 'replies.user': id }).select('+replies.audioStorage').lean();
    for (const ticket of sharedTickets) for (const reply of ticket.replies || []) {
      if (String(reply.user) === String(id)) findAssets(reply.audioStorage, assets, id);
    }
    // Proof files are personal data even when accounting totals are retained.
    const proofs = await mongoose.model('PaymentProof').find({ $or: [{ student: id }, { paidBy: id }] }).select('+storage').lean();
    proofs.forEach(row => rowAssets(row, assets, id));
    const emailIds = await mongoose.model('EmailDelivery').find({ to: job.email }).distinct('_id');
    const referralIds = await mongoose.model('ReferralEvent').find({ studentEmail: job.email }).distinct('_id');
    job.snapshot = { posts: posts.map(row => row._id), stories: stories.map(row => row._id), emailIds, referralIds, assets };
    await job.save();
  }
  for (const asset of job.snapshot.assets || []) {
    const result = await cloudinary.uploader.destroy(asset.publicId, {
      resource_type: asset.resourceType, type: asset.deliveryType, invalidate: true,
    });
    if (!['ok', 'not found'].includes(result.result)) throw new Error('Account file cleanup pending');
  }
  await mongoose.model('CommunityComment').deleteMany({ post: { $in: job.snapshot.posts } });
  await mongoose.model('CommunityReport').deleteMany({ post: { $in: job.snapshot.posts } });
  await mongoose.model('StoryInteraction').deleteMany({ story: { $in: job.snapshot.stories } });
  if (mongoose.models.CommunityReaction) await mongoose.model('CommunityReaction').deleteMany({ post: { $in: job.snapshot.posts } });
  for (const [name, fields] of Object.entries(owned)) {
    if (mongoose.models[name]) await mongoose.models[name].deleteMany(filterFor(fields, id));
  }
  // Assistant models are defined by their router, rather than model files.
  for (const name of ['AssistantThread', 'AssistantGeneration']) {
    if (mongoose.models[name]) await mongoose.models[name].deleteMany({ user: id });
  }
  await mongoose.model('PaymentProof').updateMany({ $or: [{ student: id }, { paidBy: id }] }, {
    $unset: { student: 1, paidBy: 1, storage: 1, note: 1, reviewNote: 1 },
    $set: { fileName: 'Deleted account', filePath: '' },
  });
  await mongoose.model('Invoice').updateMany({ student: id }, {
    $unset: { student: 1, application: 1, invoiceUrl: 1, adminNote: 1, stripeCheckoutPayload: 1, stripeCheckoutUrl: 1, crmIdentity: 1 },
    $set: { description: 'Retained accounting record' },
  });
  for (const [name, field] of [['StudentWalletEntry', 'student'], ['StudentRewardEntry', 'student'],
    ['AgentWalletEntry', 'agent'], ['PayoutRequest', 'agent'], ['MobileCredit', 'user']]) {
    if (mongoose.models[name]) await mongoose.models[name].updateMany({ [field]: id }, { $unset: { [field]: 1, description: 1, note: 1, notes: 1, payoutDetails: 1, reviewNote: 1 } });
  }
  await mongoose.model('EmailDelivery').deleteMany({ _id: { $in: job.snapshot.emailIds || [] } });
  await mongoose.model('ReferralEvent').deleteMany({ _id: { $in: job.snapshot.referralIds || [] } });
  await mongoose.model('IdempotencyRecord').deleteMany({ scope: { $regex: String(id) } });
  await mongoose.model('SupportTicket').updateMany({ 'replies.user': id }, { $pull: { replies: { user: id } } });
  // Clear references on shared records without removing other users' records.
  for (const model of Object.values(mongoose.models)) {
    if (model === Job || model === User) continue;
    const changes = [];
    model.schema.eachPath((field, schema) => {
      if (schema.options.ref === 'User') changes.push(model.updateMany({ [field]: id }, { $unset: { [field]: 1 } }));
      else if (schema.caster?.options?.ref === 'User') changes.push(model.updateMany({ [field]: id }, { $pull: { [field]: id } }));
    });
    for (const change of changes) await change;
  }
  // Persist completion BEFORE removing the email's unique account record.
  // Notification retries must never rescan a newly registered account that
  // subsequently uses the same email address.
  job.state = 'complete';
  job.snapshot = undefined;
  await job.save();
  await finalizeDeletion(job);
}

async function drainDeletions() {
  for (let count = 0; count < 5; count++) {
    const job = await Job.findOneAndUpdate({ state: { $in: ['pending', 'complete'] }, lockedUntil: { $lte: new Date() } },
      { $set: { lockedUntil: new Date(Date.now() + 10 * 60 * 1000) }, $inc: { attempts: 1 } }, { new: true });
    if (!job) break;
    try { await processDeletion(job); }
    catch (_) { console.error('Account deletion cleanup will retry'); }
  }
}

function startDeletionWorker() {
  const tick = () => drainDeletions().catch(() => console.error('Account deletion worker unavailable'));
  tick();
  const timer = setInterval(tick, 60000);
  timer.unref();
  return () => clearInterval(timer);
}
module.exports = { enqueueDeletion, processDeletion, drainDeletions, startDeletionWorker };
