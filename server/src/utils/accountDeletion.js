const mongoose = require('mongoose');
const User = require('../models/User');
const Job = require('../models/MaintenanceJob');
const { withLease } = require('./leaseLock');
const { queueMedia, mediaFromUrl } = require('./mediaMaintenance');

const owned = {
  StudentProfile: ['user'], Document: ['student'], Application: ['student'],
  Story: ['author'], StoryStats: ['user'], StoryVideo: ['owner'], StoryInteraction: ['user'],
  ParentLink: ['parent','student'], Friendship: ['requester','recipient'],
  ChatPreference: ['user','contact'], MobileMessage: ['sender','recipient'],
  MobileAccess: ['user'], MobileTask: ['assignedTo','student'], MobilePreferences: ['user'],
  MobileEmailCode: ['user'], MobileSession: ['user'], IdentityCredential: ['user'], IdentityChallenge: ['user'],
  Notification: ['user'], PushToken: ['user'], FavoriteItem: ['student'],
  AlumniProfile: ['user'], StudentRewardEntry: ['student'], OrientationTestResult: ['student'],
  ArrivalServiceRequest: ['student'], StudentEquivalency: ['student'], StudentInsurance: ['student'],
  ServiceRequest: ['student'], Consultation: ['student'], AccommodationBooking: ['student'],
  AgencyRequest: ['student'], SupportTicket: ['user','agent'], VerificationDocument: ['agent'],
  CommunityPost: ['author'], CommunityComment: ['author'], CommunityReport: ['reporter'],
  CommunitySuspension: ['user'],
  ActivityLog: ['user'], SharedReadReceipt: ['readBy'],
};
function loadModels() {
  // Register all schemas, including modules exporting several models.
  for (const file of require('node:fs').readdirSync(require('node:path').join(__dirname, '../models'))) {
    if (file.endsWith('.js')) require(`../models/${file}`);
  }
}
async function queueRecordMedia(record) {
  for (const storage of [record.storage, record.attachmentStorage]) await queueMedia(storage);
  if (record.image?.publicId) await queueMedia({ publicId: record.image.publicId, deliveryType: 'authenticated' });
  for (const key of ['imageUrl','videoUrl','url','filePath','resultFileUrl','cardFileUrl']) {
    await queueMedia(mediaFromUrl(record[key], ['story-images/','story-videos/','avatars/','documents/','student-documents/','chat-images/','support/','verification/']));
  }
}
async function processAccountDeletion(id) {
  return withLease(`delete-account:${id}`, async () => {
    loadModels();
    const user = await User.findById(id);
    if (user) {
      await User.updateOne({ _id: id }, { $set: { isActive: false }, $inc: { tokenVersion: 1 }, $unset: { refreshTokenHash: 1, refreshTokenExpiry: 1 } });
      await queueMedia(mediaFromUrl(user.avatar));
      await require('../models/EmailDelivery').deleteMany({ to: user.email });
    }
    const { Story, StoryInteraction } = require('../models/Stories');
    const posts = await require('../models/CommunityPost').find({ author: id }).select('_id').lean();
    await require('../models/CommunityComment').deleteMany({ post: { $in: posts.map(p => p._id) } });
    await require('../models/CommunityReport').deleteMany({ post: { $in: posts.map(p => p._id) } });
    const stories = await Story.find({ author: id }).select('_id').lean();
    const applications = await require('../models/Application').find({ student: id }).select('_id').lean();
    await require('../models/MobileWorkspace').Decision.deleteMany({ application: { $in: applications.map(a => a._id) } });
    await StoryInteraction.deleteMany({ story: { $in: stories.map(s => s._id) } });
    // Recompute visible counters affected by the departing user's contributions.
    const affectedStories = await StoryInteraction.distinct('story', { user: id, lovedAt: { $exists: true } });
    const comments = await require('../models/CommunityComment').distinct('post', { author: id });
    for (const [name, fields] of Object.entries(owned)) {
      const model = mongoose.models[name];
      if (!model) continue;
      const query = { $or: fields.map(field => ({ [field]: id })) };
      // Queue remote assets before removing records. Retry is idempotent.
      for await (const row of model.find(query).select('+storage +attachmentStorage').lean().cursor()) await queueRecordMedia(row);
      await model.deleteMany(query);
    }
    for (const story of affectedStories) {
      const count = await StoryInteraction.countDocuments({ story, lovedAt: { $exists: true } });
      await Story.updateOne({ _id: story }, { $set: { loveCount: count } });
    }
    for (const post of comments) {
      const count = await require('../models/CommunityComment').countDocuments({ post, status: 'published' });
      await require('../models/CommunityPost').updateOne({ _id: post }, { $set: { commentCount: count } });
    }
    await require('../models/MobileWorkspace').Access.updateMany({ students: id }, { $pull: { students: id } });
    await require('../models/SupportTicket').updateMany({ 'replies.user': id }, { $pull: { replies: { user: id } } });
    await require('../models/IdempotencyRecord').deleteMany({ scope: new RegExp(`(?:^|:)${id}(?:$|:)`) });
    await require('../models/WinkRoom').deleteMany({ 'state.players.id': String(id) });
    await require('../models/IdentityCredential').Challenge.deleteMany({ $or: [{ user: id }, { key: new RegExp(`:${id}(?:$|:)`) }] });
    // Financial audit records stay, without free-text personal details or profile links.
    await require('../models/Invoice').updateMany({ student: id }, { $set: { description: 'Deleted account — financial record', adminNote: '' }, $unset: { invoiceUrl: 1, application: 1, crmIdentity: 1 } });
    await require('../models/PaymentProof').updateMany({ student: id }, { $set: { note: '', reviewNote: '' } });
    await require('../models/StudentWalletEntry').updateMany({ student: id }, { $set: { notes: 'Deleted account — financial record' } });
    await User.deleteOne({ _id: id });
    await Job.deleteOne({ key: `account:${id}` });
  }, { renew: true });
}
async function deleteAccountData(user) {
  await Job.updateOne({ key: `account:${user._id}` }, { $setOnInsert: { kind: 'account', owner: user._id, dueAt: new Date() } }, { upsert: true });
  await processAccountDeletion(user._id);
}
module.exports = { deleteAccountData, processAccountDeletion };
