const asyncHandler = require("../utils/asyncHandler");
const Banner = require("../models/Banner");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");

// Public — active banners ordered for the app carousel
const getBannersPublic = asyncHandler(async (req, res) => {
  const banners = await Banner.find({ active: true }).sort({ order: 1, createdAt: 1 });
  res.json(banners);
});

// Admin — all banners
const getBannersAdmin = asyncHandler(async (req, res) => {
  const banners = await Banner.find().sort({ order: 1, createdAt: 1 });
  res.json(banners);
});

const createBanner = asyncHandler(async (req, res) => {
  const { tag, title, subtitle, actionLabel, destination, imageUrl, active, order } = req.body;
  if (!title) { res.status(400); throw new Error("title is required"); }
  const banner = await Banner.create({ tag, title, subtitle, actionLabel, destination, imageUrl, active, order });
  res.status(201).json(banner);
});

const updateBanner = asyncHandler(async (req, res) => {
  const banner = await Banner.findById(req.params.id);
  if (!banner) { res.status(404); throw new Error("Banner not found"); }
  const { tag, title, subtitle, actionLabel, destination, imageUrl, active, order } = req.body;
  Object.assign(banner, { tag, title, subtitle, actionLabel, destination, imageUrl, active, order });
  await banner.save();
  res.json(banner);
});

const deleteBanner = asyncHandler(async (req, res) => {
  const banner = await Banner.findByIdAndDelete(req.params.id);
  if (!banner) { res.status(404); throw new Error("Banner not found"); }
  res.json({ success: true });
});

const uploadBannerImage = asyncHandler(async (req, res) => {
  if (!req.file) { res.status(400); throw new Error("No file uploaded"); }
  const url = await uploadFileToCloudinary(req.file, "banners");
  res.json({ url });
});

module.exports = { getBannersPublic, getBannersAdmin, createBanner, updateBanner, deleteBanner, uploadBannerImage };
