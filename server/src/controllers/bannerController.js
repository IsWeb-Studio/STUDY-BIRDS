const { clearResponseCache } = require("../utils/responseCache");
const asyncHandler = require("../utils/asyncHandler");
const Banner = require("../models/Banner");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");

// Public — active banners ordered for the app carousel
const getBannersPublic = asyncHandler(async (req, res) => {
  const placement = req.query.placement || 'home';
  if (!['home', 'community'].includes(placement)) { res.status(400); throw new Error('Invalid banner placement'); }
  const banners = await Banner.find({ active: true, $or: [{ placement: { $in: [placement, 'both'] } }, ...(placement === 'home' ? [{ placement: { $exists: false } }] : [])] }).sort({ order: 1, createdAt: 1 });
  res.json(banners);
});

// Admin — all banners
const getBannersAdmin = asyncHandler(async (req, res) => {
  const banners = await Banner.find().sort({ order: 1, createdAt: 1 });
  res.json(banners);
});

const createBanner = asyncHandler(async (req, res) => {
  const { tag, title, subtitle, actionLabel, destination, imageUrl, active, order, placement } = req.body;
  if (placement !== undefined && !['home', 'community', 'both'].includes(placement)) { res.status(400); throw new Error('Invalid banner placement'); }
  if (!title) { res.status(400); throw new Error("title is required"); }
  const banner = await Banner.create({ tag, title, subtitle, actionLabel, destination, imageUrl, active, order, placement });
  clearResponseCache();
  res.status(201).json(banner);
});

const updateBanner = asyncHandler(async (req, res) => {
  const banner = await Banner.findById(req.params.id);
  if (!banner) { res.status(404); throw new Error("Banner not found"); }
  const { tag, title, subtitle, actionLabel, destination, imageUrl, active, order, placement } = req.body;
  if (placement !== undefined && !['home', 'community', 'both'].includes(placement)) { res.status(400); throw new Error('Invalid banner placement'); }
  const fields = { tag, title, subtitle, actionLabel, destination, imageUrl, active, order, placement };
  for (const [key, value] of Object.entries(fields)) if (value !== undefined) banner[key] = value;
  await banner.save();
  clearResponseCache();
  res.json(banner);
});

const deleteBanner = asyncHandler(async (req, res) => {
  const banner = await Banner.findByIdAndDelete(req.params.id);
  if (!banner) { res.status(404); throw new Error("Banner not found"); }
  clearResponseCache();
  res.json({ success: true });
});

const uploadBannerImage = asyncHandler(async (req, res) => {
  if (!req.file) { res.status(400); throw new Error("No file uploaded"); }
  const media = await uploadFileToCloudinary(req.file, "banners");
  res.json({ url: media.url });
});

module.exports = { getBannersPublic, getBannersAdmin, createBanner, updateBanner, deleteBanner, uploadBannerImage };
