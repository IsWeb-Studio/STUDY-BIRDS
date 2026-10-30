const asyncHandler = require('../utils/asyncHandler');
const User = require('../models/User');
const uploads = require('../utils/uploadToCloudinary');
const { serializeUser } = require('./authController');

exports.updateName = asyncHandler(async (req, res) => {
  const body = req.body || {};
  if (Object.keys(body).some(key => key !== 'name') || typeof body.name !== 'string'
      || !body.name.trim() || body.name.trim().length > 120) {
    return res.status(400).json({ message: 'Invalid name' });
  }
  const user = await User.findByIdAndUpdate(req.user._id,
    { $set: { name: body.name.trim() } }, { new: true, runValidators: true });
  if (!user) return res.status(404).json({ message: 'Account unavailable' });
  res.json({ user: serializeUser(user) });
});

exports.uploadAvatar = asyncHandler(async (req, res) => {
  if (!req.file || !['image/jpeg', 'image/png', 'image/webp'].includes(req.file.mimetype)) {
    return res.status(415).json({ message: 'Choose a JPEG, PNG or WebP image' });
  }
  const image = await uploads.uploadFileToCloudinary(req.file, `account-avatars/${req.user._id}`);
  const user = await User.findByIdAndUpdate(req.user._id,
    { $set: { avatar: image.secure_url || image.url } }, { new: true, runValidators: true });
  if (!user) return res.status(404).json({ message: 'Account unavailable' });
  res.json({ user: serializeUser(user) });
});
