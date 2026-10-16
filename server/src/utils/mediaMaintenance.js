const Job = require('../models/MaintenanceJob');
const { Story } = require('../models/Stories');
const { cloudinary, ensureCloudinaryConfigured } = require('../config/cloudinary');
const { withLease } = require('./leaseLock');

async function queueMedia(media, dueAt = new Date()) {
  if (!media?.publicId) return;
  const resourceType = media.resourceType || 'image';
  const deliveryType = media.deliveryType || 'upload';
  await Job.updateOne({ key: `media:${resourceType}:${deliveryType}:${media.publicId}` }, {
    $set: { kind: 'media', publicId: media.publicId, resourceType, deliveryType,
      url: media.url || '', dueAt },
  }, { upsert: true });
}
// Only our Cloudinary originals, with an explicitly allowed folder, may be deleted.
function mediaFromUrl(value, folders = ['story-images/', 'story-videos/', 'avatars/']) {
  try {
    const url = new URL(value);
    const parts = url.pathname.split('/').filter(Boolean);
    if (url.protocol !== 'https:' || url.hostname !== 'res.cloudinary.com' ||
        parts[0] !== process.env.CLOUDINARY_CLOUD_NAME || !['image','video','raw'].includes(parts[1]) || parts[2] !== 'upload') return null;
    let rest = parts.slice(3);
    if (/^v\d+$/.test(rest[0])) rest = rest.slice(1);
    const publicId = rest.join('/').replace(/\.[^/.]+$/, '');
    if (!folders.some(folder => publicId.startsWith(folder))) return null;
    return { publicId, resourceType: parts[1], url: value };
  } catch { return null; }
}
async function cleanMedia(job) {
  if (job.url && await require('../models/User').exists({ avatar: job.url, isActive: true })) {
    await Job.deleteOne({ _id: job._id }); return;
  }
  if (job.url) {
    const active = await Story.findOne({ $or: [{ imageUrl: job.url }, { videoUrl: job.url }], expiresAt: { $gt: new Date() } }).sort({ expiresAt: -1 }).lean();
    if (active) { await Job.updateOne({ _id: job._id }, { $set: { dueAt: active.expiresAt } }); return; }
  }
  ensureCloudinaryConfigured();
  const result = await cloudinary.uploader.destroy(job.publicId, { resource_type: job.resourceType, type: job.deliveryType, invalidate: true });
  if (!['ok', 'not found'].includes(result?.result)) throw new Error('Media deletion not confirmed');
  await Job.deleteOne({ _id: job._id });
}
async function runMaintenance() {
  return withLease('media-account-maintenance', async () => {
    // Backfill existing expired stories, retaining their replay-protection records.
    const expired = await Story.find({ expiresAt: { $lte: new Date() }, mediaCleanupQueued: { $ne: true } }).limit(100).lean();
    for (const story of expired) {
      for (const url of [story.imageUrl, story.videoUrl]) await queueMedia(mediaFromUrl(url));
      await Story.updateOne({ _id: story._id }, { $set: { mediaCleanupQueued: true } });
    }
    for (const job of await Job.find({ dueAt: { $lte: new Date() } }).sort({ dueAt: 1 }).limit(30).lean()) {
      try {
        if (job.kind === 'account') await require('./accountDeletion').processAccountDeletion(job.owner);
        else await cleanMedia(job);
      } catch (error) {
        await Job.updateOne({ _id: job._id }, { $inc: { attempts: 1 }, $set: { dueAt: new Date(Date.now() + Math.min(3600000, 60000 * (job.attempts + 1))) } });
        console.error('Maintenance retry scheduled', job.kind, error.message);
      }
    }
  }, { renew: true, waitMs: 0 });
}
function startMaintenance() {
  const tick = () => runMaintenance().catch(error => { if (error.statusCode !== 409) console.error('Maintenance failed', error.message); });
  tick(); const timer = setInterval(tick, 60000); timer.unref();
  return () => clearInterval(timer);
}
module.exports = { queueMedia, mediaFromUrl, runMaintenance, startMaintenance };
