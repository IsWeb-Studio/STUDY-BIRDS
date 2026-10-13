const express = require("express");
const mongoose = require("mongoose");
const Settings = require("../models/MobileSettings");
const Content = require("../models/MobileContent");
const Request = require("../models/MobileRequest");
const Notification = require("../models/Notification");
const User = require("../models/User");
const Document = require("../models/Document");
const Profile = require("../models/StudentProfile");
const Ticket = require("../models/SupportTicket");
const { defaults, contentModules, validateSettings, validateContent } = require("../utils/mobileConfig");
const { protect, authorize } = require("../middleware/authMiddleware");
const asyncHandler = require("../utils/asyncHandler");
const router = express.Router();
const config = async () => {
  const saved = await Settings.findOne({ key: 'mobile' }).lean();
  const initial = defaults(); const current = saved?.config || initial;
  // Add newly introduced screens without changing the administrator's saved settings.
  return { ...initial, ...current, modules: initial.modules.map(item => current.modules?.find(m => m.key === item.key) || item), revision: saved?.revision || 0 };
};
const bad = (res, message, code = 400) => { res.status(code); throw new Error(message); };
const validId = (id, res) => { if (!mongoose.isValidObjectId(id)) bad(res, "Invalid identifier"); };
const validated = (fn, body, res) => { try { return fn(body); } catch (e) { bad(res, e.message); } };
router.get("/config", asyncHandler(async (req, res) => { res.set("Cache-Control", "no-store"); res.json(await config()); }));
router.get("/content", asyncHandler(async (req, res) => {
  if (!contentModules.includes(req.query.section)) bad(res, "Invalid section");
  const settings = await config();
  if (settings.maintenance || !settings.modules.find((m) => m.key === req.query.section)?.enabled) return res.json([]);
  res.json(await Content.find({ section: req.query.section, published: true }).sort({ order: 1, createdAt: -1 }).lean());
}));
router.get("/requests", protect, authorize("student"), asyncHandler(async (req, res) => {
  res.json(await Request.find({ user: req.user._id }).sort({ createdAt: -1 }).lean());
}));
router.post("/requests", protect, authorize("student"), asyncHandler(async (req, res) => {
  validId(req.body.contentId, res);
  if (typeof req.body.message !== "string" || !req.body.message.trim() || req.body.message.length > 4000) bad(res, "Please provide request details (maximum 4000 characters)");
  const item = await Content.findOne({ _id: req.body.contentId, published: true, requestable: true });
  if (!item) bad(res, "Service is unavailable", 404);
  const settings = await config();
  if (settings.maintenance || !settings.modules.find((m) => m.key === item.section)?.enabled) bad(res, "Service is currently disabled", 403);
  res.status(201).json(await Request.create({ user: req.user._id, content: item._id, title: item.title, section: item.section, message: req.body.message.trim() }));
}));
router.use("/admin", protect, authorize("admin"));
router.post("/tickets/:id/reply", protect, authorize("student", "partner"), asyncHandler(async (req, res) => {
  validId(req.params.id, res);
  if (typeof req.body.message !== "string" || !req.body.message.trim() || req.body.message.length > 4000) bad(res, "Message is required (maximum 4000 characters)");
  const ticket = await Ticket.findOneAndUpdate({ _id: req.params.id, requesterRole: req.user.role,
    $or: [{ user: req.user._id }, { agent: req.user._id }], status: { $ne: "closed" } },
    { $push: { replies: { message: req.body.message.trim(), fromRole: req.user.role, user: req.user._id } }, $set: { status: "open" } }, { new: true, runValidators: true });
  if (!ticket) bad(res, "Ticket is unavailable or closed", 404);
  res.json(ticket);
}));
router.patch("/admin/documents/:id", asyncHandler(async (req, res) => {
  validId(req.params.id, res);
  if (!["pending", "verified", "rejected"].includes(req.body.status)) bad(res, "Invalid document status");
  const document = await Document.findByIdAndUpdate(req.params.id, { $set: { status: req.body.status } }, { new: true });
  if (!document) bad(res, "Document not found", 404);
  res.json(document);
}));
router.patch("/admin/students/:id/stage", asyncHandler(async (req, res) => {
  validId(req.params.id, res);
  if (!["file-received", "applying", "preliminary-accepted", "first-payment", "final-accepted", "travel-and-settlement"].includes(req.body.applicationStage)) bad(res, "Invalid journey stage");
  if (!await User.exists({ _id: req.params.id, role: "student" })) bad(res, "Student not found", 404);
  res.json(await Profile.findOneAndUpdate({ user: req.params.id }, { $set: { applicationStage: req.body.applicationStage } }, { new: true, upsert: true, runValidators: true }));
}));
router.get("/admin/settings", asyncHandler(async (req, res) => res.json(await config())));
router.put("/admin/settings", asyncHandler(async (req, res) => {
  const clean = validated(validateSettings, req.body, res);
  if (!Number.isInteger(req.body.revision) || req.body.revision < 0) bad(res, "Invalid revision");
  // Initialize separately so concurrent first saves are also checked atomically.
  await Settings.updateOne({ key: "mobile" }, { $setOnInsert: { config: defaults(), revision: 0 } }, { upsert: true });
  const saved = await Settings.findOneAndUpdate({ key: "mobile", revision: req.body.revision },
    { $set: { config: clean, updatedBy: req.user._id }, $inc: { revision: 1 } }, { new: true });
  if (!saved) bad(res, "Settings changed in another session. Reload before saving.", 409);
  res.json({ ...saved.config, revision: saved.revision });
}));
router.get("/admin/content", asyncHandler(async (req, res) => res.json(await Content.find().sort({ section: 1, order: 1 }).lean())));
router.post("/admin/content", asyncHandler(async (req, res) => res.status(201).json(await Content.create(validated(validateContent, req.body, res)))));
router.put("/admin/content/:id", asyncHandler(async (req, res) => {
  validId(req.params.id, res);
  const item = await Content.findByIdAndUpdate(req.params.id, { $set: validated(validateContent, req.body, res) }, { new: true, runValidators: true });
  if (!item) bad(res, "Content not found", 404);
  res.json(item);
}));
router.delete("/admin/content/:id", asyncHandler(async (req, res) => {
  validId(req.params.id, res);
  if (!await Content.findByIdAndDelete(req.params.id)) bad(res, "Content not found", 404);
  res.json({ deleted: true });
}));
router.get("/admin/requests", asyncHandler(async (req, res) => res.json(await Request.find().populate("user", "name email").sort({ createdAt: -1 }).lean())));
router.patch("/admin/requests/:id", asyncHandler(async (req, res) => {
  validId(req.params.id, res);
  if (!["submitted", "in-progress", "completed", "cancelled"].includes(req.body.status) || typeof req.body.adminNote !== "string" || req.body.adminNote.length > 4000) bad(res, "Invalid request update");
  const item = await Request.findByIdAndUpdate(req.params.id, { $set: { status: req.body.status, adminNote: req.body.adminNote } }, { new: true });
  if (!item) bad(res, "Request not found", 404);
  res.json(item);
}));
router.post("/admin/notifications", asyncHandler(async (req, res) => {
  validId(req.body.userId, res);
  if (typeof req.body.title !== "string" || !req.body.title.trim() || req.body.title.length > 150 || typeof req.body.message !== "string" || !req.body.message.trim() || req.body.message.length > 4000) bad(res, "Title and message are required");
  if (!await User.exists({ _id: req.body.userId, role: { $in: ['student', 'partner', 'parent', 'university', 'employee'] } })) bad(res, "Account not found", 404);
  res.status(201).json(await Notification.create({ user: req.body.userId, title: req.body.title.trim(), message: req.body.message.trim(), type: "info" }));
}));
module.exports = router;
