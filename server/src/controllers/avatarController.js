const run = require('../utils/asyncHandler');
const User = require('../models/User');
const { uploadFileToCloudinary } = require('../utils/uploadToCloudinary');
const { queueMedia, mediaFromUrl } = require('../utils/mediaMaintenance');
const { serializeUser } = require('./authController');
const { withLease } = require('../utils/leaseLock');
module.exports = run(async (req, res) => withLease(`avatar:${req.user._id}`, async () => {
  if (!req.file || !['image/jpeg','image/png','image/webp'].includes(req.file.mimetype)) return res.status(415).json({ message: 'اختر صورة JPG أو PNG أو WebP.' });
  const media = await uploadFileToCloudinary(req.file, `avatars/${req.user._id}`);
  // Track the new asset before linking it; failures cannot leak an untracked upload.
  await queueMedia(media, new Date(Date.now() + 86400000));
  const previous = await User.findOneAndUpdate({ _id: req.user._id, isActive: true }, { $set: { avatar: media.url } }, { new: false });
  if (!previous) return res.sendStatus(401);
  await require('../models/MaintenanceJob').deleteOne({ key: `media:${media.resourceType || 'image'}:upload:${media.publicId}` });
  await queueMedia(mediaFromUrl(previous.avatar));
  const user = await User.findById(req.user._id);
  res.json({ user: serializeUser(user) });
}, { renew: true }));
