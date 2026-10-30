const {crmPagination,crmPage}=require('../utils/crmPagination');
const mongoose = require("mongoose");
const asyncHandler = require("../utils/asyncHandler");
const CommunityPost = require("../models/CommunityPost");
const Reaction = require("../models/CommunityReaction");
const images = require("../utils/chatImages");
const mediaStorage = require("../config/cloudinary");
const CommunityComment = require("../models/CommunityComment");
const CommunityReport = require("../models/CommunityReport");
const CommunityModerationLog = require("../models/CommunityModerationLog");
const Country = require("../models/Country");
const University = require("../models/University");
const StudyField = require("../models/StudyField");
const Notification = require("../models/Notification");
const User = require("../models/User");
const CommunitySuspension = require("../models/CommunitySuspension");
const CommunitySettings = require("../models/CommunitySettings");
const { findBlockedTerm } = require("../utils/communityTerms");
const { blockedIds, isBlocked } = require('../utils/userBlocks');

const { COMMUNITY_TOPICS } = CommunityPost;
const { REPORT_REASONS } = CommunityReport;
async function removeImage(image) {
  const storage = mediaStorage;
  storage.ensureCloudinaryConfigured();
  const result = await storage.cloudinary.uploader.destroy(image.publicId,
    { resource_type: 'image', type: 'authenticated', invalidate: true });
  if (!['ok', 'not found'].includes(result.result)) throw new Error('Image deletion pending');
}
async function presentPosts(posts, user) {
  const ids = posts.map(post => post._id);
  const [totals, mine] = await Promise.all([
    Reaction.aggregate([{ $match: { post: { $in: ids } } },
      { $group: { _id: { post: '$post', reaction: '$reaction' }, count: { $sum: 1 } } }]),
    Reaction.find({ post: { $in: ids }, user }).select('post reaction').lean(),
  ]);
  return posts.map(post => {
    const reactionCounts = {};
    for (const row of totals) if (String(row._id.post) === String(post._id)) reactionCounts[row._id.reaction] = row.count;
    const myReaction = mine.find(row => String(row.post) === String(post._id))?.reaction || null;
    return { ...post, isAdminPost: post.author?.role === 'admin',
      imagePath: post.hasImage ? `/community/posts/${post._id}/image` : null,
      reactionCounts, reactionTotal: Object.values(reactionCounts).reduce((sum, value) => sum + value, 0),
      myReaction, likedByMe: myReaction === 'like',
      likeCount: Object.values(reactionCounts).reduce((sum, value) => sum + value, 0) };
  });
}
const STUDENT_POST_FIELDS = "-moderationNote -moderatedBy -reportCount";
const validId = (value) => typeof value === "string" && mongoose.isValidObjectId(value);
const populatePost = (query) => query
  .populate({ path: "author", select: "name avatar role linkedUniversity", populate: { path: "linkedUniversity", select: "name logo" } }).populate("country", "name").populate("university", "name").populate("studyField", "name");

// Suspended students can still read, but not post, comment or report.
async function rejectIfSuspended(req, res) {
  const suspension = await CommunitySuspension.activeFor(req.user._id);
  if (!suspension) return false;
  res.status(403).json({ message: "You are suspended from posting in the community", suspendedUntil: suspension.until, reason: suspension.reason });
  return true;
}

// 422 (not 400) so clients can tell "rephrase this" apart from invalid input.
async function rejectIfBlocked(res, text) {
  const settings = await CommunitySettings.findOne({ key: "community" }).lean();
  if (!findBlockedTerm(text, settings?.blockedTerms)) return false;
  res.status(422).json({ message: "Your text contains words that are not allowed in the community" });
  return true;
}

// ---- Students: browse, post, comment, report --------------------------------

const getMyStatus = asyncHandler(async (req, res) => {
  const suspension = await CommunitySuspension.activeFor(req.user._id);
  res.json(suspension ? { suspended: true, until: suspension.until, reason: suspension.reason } : { suspended: false });
});

const listPosts = asyncHandler(async (req, res) => {
  const { topic, country, university, studyField, mine, admin, author } = req.query;
  if (author !== undefined && (!validId(author) || mine === '1' || admin === '1')) return res.status(400).json({ message: 'Invalid author filter' });
  if (admin && admin !== "1" || admin === "1" && mine === "1") return res.status(400).json({ message: "Invalid author filter" });
  if (topic && !COMMUNITY_TOPICS.includes(topic)) return res.status(400).json({ message: "Invalid topic" });
  for (const value of [country, university, studyField]) {
    if (value && !validId(value)) return res.status(400).json({ message: "Invalid filter" });
  }
  // "mine" shows the student's own posts in every status, with the moderation
  // note, so a hidden post never silently disappears from its author.
  const query = mine === "1" ? { author: req.user._id } : { status: "published" };
  if (mine !== '1') query.author = { $nin: await blockedIds(req.user._id) };
  if (author) query.author.$eq = author;
  if (admin === '1') query.author.$in = await User.distinct('_id', { role: 'admin', isActive: true });
  if (topic) query.topic = topic;
  if (country) query.country = country;
  if (university) query.university = university;
  if (studyField) query.studyField = studyField;
  const posts = await populatePost(CommunityPost.find(query).select(mine === "1" ? "-moderatedBy -reportCount" : STUDENT_POST_FIELDS))
    .sort({ createdAt: -1 }).limit(100).lean();
  res.json(await presentPosts(posts, req.user._id));
});

const createPost = asyncHandler(async (req, res) => {
  const { title = "", body, topic = "other", country, university, studyField, operationId } = req.body;
  if (typeof title !== "string" || title.length > 150
    || typeof body !== "string" || !body.trim() || body.length > 5000
    || !COMMUNITY_TOPICS.includes(topic)
    || (country && !validId(country)) || (university && !validId(university)) || (studyField && !validId(studyField))) {
    return res.status(400).json({ message: "Invalid post" });
  }
  const [countryOk, universityOk, fieldOk] = await Promise.all([
    !country || Country.exists({ _id: country }),
    !university || University.exists({ _id: university }),
    !studyField || StudyField.exists({ _id: studyField }),
  ]);
  if (!countryOk || !universityOk || !fieldOk) return res.status(400).json({ message: "Invalid post" });
  if (await rejectIfSuspended(req, res) || await rejectIfBlocked(res, `${title}\n${body}`)) return;
  if (operationId != null && (typeof operationId !== 'string' || !/^[A-Za-z0-9_-]{8,100}$/.test(operationId))) return res.status(400).json({ message: 'Invalid operation' });
  if (req.file && !operationId) return res.status(400).json({ message: 'Operation required' });
  if (operationId) {
    const existing = await CommunityPost.findOne({ author: req.user._id, operationId });
    if (existing) return res.json((await presentPosts([await populatePost(CommunityPost.findById(existing._id).select(STUDENT_POST_FIELDS)).lean()], req.user._id))[0]);
  }
  if (req.file && !['image/jpeg', 'image/png', 'image/webp'].includes(req.file.mimetype)) return res.status(415).json({ message: 'Choose a JPEG, PNG or WebP image' });
  let image;
  try {
    await CommunityPost.init();
    if (req.file) image = { ...await images.uploadChatImage(req.file, req.user._id), resourceType: 'image', deliveryType: 'authenticated' };
    let post;
    try {
      post = await CommunityPost.create({ author: req.user._id, title: title.trim(), body: body.trim(), topic,
        country: country || undefined, university: university || undefined, studyField: studyField || undefined,
        operationId, image, hasImage: !!image });
    } catch (error) {
      if (error.code !== 11000 || !operationId) throw error;
      post = await CommunityPost.findOne({ author: req.user._id, operationId });
      if (!post) throw error;
    }
    const data = await populatePost(CommunityPost.findById(post._id).select(STUDENT_POST_FIELDS)).lean();
    res.status(201).json((await presentPosts([data], req.user._id))[0]);
  } finally {
    try { if (image && !await CommunityPost.exists({ 'image.publicId': image.publicId })) await removeImage(image); }
    catch (_) { console.warn('Community image cleanup needs retry'); }
  }
});

const getPost = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: "Post not found" });
  const post = await populatePost(CommunityPost.findOne({ _id: req.params.id, status: "published" }).select(STUDENT_POST_FIELDS)).lean();
  if (!post) return res.status(404).json({ message: "Post not found" });
  if (post.author && await isBlocked(req.user._id, post.author._id)) return res.status(404).json({ message: 'Post not found' });
  const comments = await CommunityComment.find({ post: post._id, status: "published", author: { $nin: await blockedIds(req.user._id) } })
    .select("-moderationNote -moderatedBy -reportCount").populate("author", "name avatar").sort({ createdAt: 1 }).lean();
  res.json({ post: (await presentPosts([post], req.user._id))[0], comments });
});

const getPostImage = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: 'Post unavailable' });
  const post = await CommunityPost.findById(req.params.id).select('+image');
  const staff = require('../middleware/employeeAccess').hasSection(req.user, 'community');
  if (!post || !post.image?.publicId || (!staff && String(post.author) !== String(req.user._id) && post.status !== 'published')
      || (!staff && await isBlocked(req.user._id, post.author))) return res.status(404).json({ message: 'Image unavailable' });
  const bytes = await images.readChatImage(post.image);
  res.set({ 'Content-Type': 'image/jpeg', 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' }).send(bytes);
});

const setReaction = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: 'Post unavailable' });
  const reaction = req.method === 'DELETE' ? null : req.path.endsWith('/like') ? 'like' : req.body.reaction;
  if (reaction !== null && !Reaction.REACTIONS.includes(reaction)) return res.status(400).json({ message: 'Invalid reaction' });
  const post = await CommunityPost.findOne({ _id: req.params.id, status: 'published' }).lean();
  if (!post || await isBlocked(req.user._id, post.author)) return res.status(404).json({ message: 'Post unavailable' });
  if (await rejectIfSuspended(req, res)) return;
  await Reaction.init();
  const filter = { post: post._id, user: req.user._id };
  if (reaction === null) await Reaction.deleteOne(filter);
  else {
    try { await Reaction.findOneAndUpdate(filter, { $set: { reaction } }, { upsert: true, runValidators: true }); }
    catch (error) { if (error.code !== 11000) throw error; await Reaction.updateOne(filter, { $set: { reaction } }); }
  }
  const result = (await presentPosts([post], req.user._id))[0];
  res.json({ reactionCounts: result.reactionCounts, reactionTotal: result.reactionTotal,
    myReaction: result.myReaction, liked: result.likedByMe, likeCount: result.likeCount });
});

const editOwnPost = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: 'Post unavailable' });
  const { title = '', body } = req.body;
  if (typeof title !== 'string' || title.length > 150 || typeof body !== 'string' || !body.trim() || body.length > 5000) return res.status(400).json({ message: 'Invalid post' });
  const post = await CommunityPost.findOne({ _id: req.params.id, author: req.user._id });
  if (!post) return res.status(404).json({ message: 'Post unavailable' });
  if (await rejectIfSuspended(req, res) || await rejectIfBlocked(res, `${title}\n${body}`)) return;
  await CommunityPost.updateOne({ _id: post._id, author: req.user._id }, { $set: { title: title.trim(), body: body.trim() } });
  res.json({ updated: true });
});
const editOwnComment = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: 'Comment unavailable' });
  const { body } = req.body;
  if (typeof body !== 'string' || !body.trim() || body.length > 2000) return res.status(400).json({ message: 'Invalid comment' });
  const comment = await CommunityComment.findOne({ _id: req.params.id, author: req.user._id });
  if (!comment || !await CommunityPost.exists({ _id: comment.post, status: 'published' })) return res.status(404).json({ message: 'Comment unavailable' });
  if (await rejectIfSuspended(req, res) || await rejectIfBlocked(res, body)) return;
  await CommunityComment.updateOne({ _id: comment._id, author: req.user._id }, { $set: { body: body.trim() } });
  res.json({ updated: true });
});

const deleteOwnPost = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: "Post not found" });
  const post = await CommunityPost.findOne({ _id: req.params.id, author: req.user._id }).select('+image');
  if (!post) return res.status(404).json({ message: "Post not found" });
  if (post.image?.publicId) await removeImage(post.image);
  await CommunityPost.deleteOne({ _id: post._id, author: req.user._id });
  await Reaction.deleteMany({ post: post._id });
  await CommunityComment.deleteMany({ post: post._id });
  await CommunityReport.deleteMany({ post: post._id });
  res.json({ message: "Post deleted" });
});

const createComment = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: "Post not found" });
  const { body } = req.body;
  if (typeof body !== "string" || !body.trim() || body.length > 2000) return res.status(400).json({ message: "Invalid comment" });
  const post = await CommunityPost.findOne({ _id: req.params.id, status: "published" });
  if (!post) return res.status(404).json({ message: "Post not found" });
  if (await isBlocked(req.user._id, post.author)) return res.status(404).json({ message: 'Post not found' });
  if (await rejectIfSuspended(req, res) || await rejectIfBlocked(res, body)) return;
  const comment = await CommunityComment.create({ post: post._id, author: req.user._id, body: body.trim() });
  await CommunityPost.updateOne({ _id: post._id }, { $inc: { commentCount: 1 } });
  res.status(201).json(await CommunityComment.findById(comment._id).select("-moderationNote -moderatedBy -reportCount").populate("author", "name avatar").lean());
});

const deleteOwnComment = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: "Comment not found" });
  const comment = await CommunityComment.findOneAndDelete({ _id: req.params.id, author: req.user._id });
  if (!comment) return res.status(404).json({ message: "Comment not found" });
  // Hidden comments were already taken out of the count when they were hidden.
  if (comment.status === "published") await CommunityPost.updateOne({ _id: comment.post, commentCount: { $gt: 0 } }, { $inc: { commentCount: -1 } });
  await CommunityReport.deleteMany({ targetType: "comment", target: comment._id });
  res.json({ message: "Comment deleted" });
});

async function report(req, res, targetType) {
  if (!validId(req.params.id)) return res.status(404).json({ message: "Content not found" });
  const { reason, details = "" } = req.body;
  if (!REPORT_REASONS.includes(reason) || typeof details !== "string" || details.length > 500) {
    return res.status(400).json({ message: "Invalid report" });
  }
  const Model = targetType === "post" ? CommunityPost : CommunityComment;
  const target = await Model.findOne({ _id: req.params.id, status: "published" });
  if (!target) return res.status(404).json({ message: "Content not found" });
  const postId = targetType === "post" ? target._id : target.post;
  if (targetType === "comment" && !(await CommunityPost.exists({ _id: postId, status: "published" }))) {
    return res.status(404).json({ message: "Content not found" });
  }
  if (String(target.author) === String(req.user._id)) return res.status(400).json({ message: "You cannot report your own content" });
  if (await rejectIfSuspended(req, res)) return;
  // The unique index is what enforces one report per student; make sure it exists.
  await CommunityReport.init();
  try {
    await CommunityReport.create({ targetType, target: target._id, post: postId, reporter: req.user._id, reason, details: details.trim() });
  } catch (error) {
    if (error.code === 11000) return res.status(409).json({ message: "You already reported this content" });
    throw error;
  }
  await Model.updateOne({ _id: target._id }, { $inc: { reportCount: 1 } });
  res.status(201).json({ message: "Report received" });
}

const reportPost = asyncHandler((req, res) => report(req, res, "post"));
const reportComment = asyncHandler((req, res) => report(req, res, "comment"));

// ---- Staff moderation (mounted under /admin, gated by the 'community'
// employee section) ------------------------------------------------------------

async function openReportCounts(postIds) {
  const rows = await CommunityReport.aggregate([
    { $match: { status: "open", post: { $in: postIds } } },
    { $group: { _id: "$post", count: { $sum: 1 } } },
  ]);
  return new Map(rows.map((row) => [String(row._id), row.count]));
}

const listPostsAdmin = asyncHandler(async (req, res) => {
  const query = {};
  if (req.query.status && ["published", "hidden"].includes(req.query.status)) query.status = req.query.status;
  if (req.query.topic && COMMUNITY_TOPICS.includes(req.query.topic)) query.topic = req.query.topic;
  // "reported" = posts with any open report on the post or one of its comments.
  if (req.query.reported === "1") query._id = { $in: await CommunityReport.distinct("post", { status: "open" }) };
  const pagination=crmPagination(req.query);
  const posts = await CommunityPost.find(query).populate("author", "name email").populate("moderatedBy", "name")
    .populate("studyField", "name").sort({ createdAt: -1, _id:-1 }).skip(pagination?.skip || 0).limit(pagination?.limit || 300).lean();
  const counts = await openReportCounts(posts.map((post) => post._id));
  const items=posts.map(post=>({...post,openReports:counts.get(String(post._id)) || 0}));
  res.json(pagination?crmPage(items,await CommunityPost.countDocuments(query),pagination):items);
});

const getPostAdmin = asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(404).json({ message: "Post not found" });
  const post = await CommunityPost.findById(req.params.id).populate("author", "name email").populate("moderatedBy", "name")
    .populate("country", "name").populate("university", "name").populate("studyField", "name").lean();
  if (!post) return res.status(404).json({ message: "Post not found" });
  const [comments, reports, log] = await Promise.all([
    CommunityComment.find({ post: post._id }).populate("author", "name email").populate("moderatedBy", "name").sort({ createdAt: 1 }).lean(),
    CommunityReport.find({ post: post._id }).populate("reporter", "name email").populate("reviewedBy", "name").sort({ createdAt: -1 }).lean(),
    CommunityModerationLog.find({ post: post._id }).populate("actor", "name").sort({ createdAt: -1 }).lean(),
  ]);
  res.json({ post: (await presentPosts([post], req.user._id))[0], comments, reports, log });
});

const listReportsAdmin = asyncHandler(async (req, res) => {
  const status = ["open", "resolved", "dismissed"].includes(req.query.status) ? req.query.status : "open";
  const pagination=crmPagination(req.query);
  const reports = await CommunityReport.find({ status }).populate("reporter", "name email").populate("post", "title status")
    .populate("reviewedBy", "name").sort({ createdAt: -1, _id:-1 }).skip(pagination?.skip || 0).limit(pagination?.limit || 300).lean();
  res.json(pagination?crmPage(reports,await CommunityReport.countDocuments({status}),pagination):reports);
});

const listModerationLogAdmin = asyncHandler(async (req, res) => {
  const query = {};
  if (req.query.post && validId(req.query.post)) query.post = req.query.post;
  if (req.query.subject && validId(req.query.subject)) query.subject = req.query.subject;
  const pagination=crmPagination(req.query);
  const items=await CommunityModerationLog.find(query).populate("actor", "name").populate("subject", "name email").populate("post", "title")
    .sort({ createdAt: -1, _id:-1 }).skip(pagination?.skip || 0).limit(pagination?.limit || 300).lean();
  res.json(pagination?crmPage(items,await CommunityModerationLog.countDocuments(query),pagination):items);
});

// ---- Suspensions -------------------------------------------------------------

const listSuspensionsAdmin = asyncHandler(async (req, res) => {
  const active = await CommunitySuspension.find({ $or: [{ until: null }, { until: { $gt: new Date() } }] })
    .populate("user", "name email").populate("suspendedBy", "name").sort({ createdAt: -1 }).lean();
  res.json(active);
});

const suspendUser = asyncHandler(async (req, res) => {
  const { user: userId, days = null, reason } = req.body;
  if (!validId(userId) || typeof reason !== "string" || !reason.trim() || reason.length > 500
    || (days !== null && (!Number.isInteger(days) || days < 1 || days > 365))) {
    return res.status(400).json({ message: "Invalid suspension" });
  }
  const student = await User.findOne({ _id: userId, role: "student" }).select("_id").lean();
  if (!student) return res.status(404).json({ message: "Student not found" });
  const until = days === null ? null : new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  const wasActive = Boolean(await CommunitySuspension.activeFor(student._id));
  const suspension = await CommunitySuspension.findOneAndUpdate(
    { user: student._id },
    { until, reason: reason.trim(), suspendedBy: req.user._id },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  await CommunityModerationLog.create({
    actor: req.user._id, targetType: "user", target: student._id, subject: student._id,
    fromStatus: wasActive ? "suspended" : "active", toStatus: "suspended", note: reason.trim(), suspendedUntil: until || undefined,
  });
  await Notification.create({
    user: student._id,
    title: "تم إيقافك عن النشر في مجتمع الطلاب",
    message: `${until ? `حتى ${until.toISOString().slice(0, 10)}` : "حتى يرفعه فريق الإشراف"}. السبب: ${reason.trim()}. ما زال بإمكانك قراءة المجتمع.`,
    type: "warning",
    link: "/student/community",
  });
  res.status(201).json(await CommunitySuspension.findById(suspension._id).populate("user", "name email").lean());
});

const liftSuspension = asyncHandler(async (req, res) => {
  if (!validId(req.params.userId)) return res.status(404).json({ message: "Suspension not found" });
  const note = typeof req.body?.note === "string" ? req.body.note.trim().slice(0, 500) : "";
  const removed = await CommunitySuspension.findOneAndDelete({ user: req.params.userId });
  if (!removed) return res.status(404).json({ message: "Suspension not found" });
  await CommunityModerationLog.create({
    actor: req.user._id, targetType: "user", target: removed.user, subject: removed.user,
    fromStatus: "suspended", toStatus: "active", note,
  });
  await Notification.create({
    user: removed.user, title: "رُفع إيقافك في مجتمع الطلاب",
    message: "يمكنك النشر والتعليق في المجتمع مجددًا.", type: "success", link: "/student/community",
  });
  res.json({ message: "Suspension lifted" });
});

// ---- Blocked terms -------------------------------------------------------------

const getSettingsAdmin = asyncHandler(async (req, res) => {
  const settings = await CommunitySettings.findOne({ key: "community" }).populate("updatedBy", "name").lean();
  res.json(settings || { blockedTerms: [] });
});

const updateSettingsAdmin = asyncHandler(async (req, res) => {
  const { blockedTerms } = req.body;
  if (!Array.isArray(blockedTerms) || blockedTerms.length > 300
    || blockedTerms.some((term) => typeof term !== "string" || !term.trim() || term.trim().length > 60)) {
    return res.status(400).json({ message: "Invalid blocked terms (up to 300 terms, 60 characters each)" });
  }
  const terms = [...new Set(blockedTerms.map((term) => term.trim()))];
  const settings = await CommunitySettings.findOneAndUpdate(
    { key: "community" }, { blockedTerms: terms, updatedBy: req.user._id }, { upsert: true, new: true, setDefaultsOnInsert: true }
  ).populate("updatedBy", "name").lean();
  res.json(settings);
});

// Applies one moderation decision: status change (guarded against concurrent
// moderators), closing the target's open reports, an audit entry, and a notice
// to the author when their content is hidden.
async function moderate(req, res, targetType) {
  const label = targetType === "post" ? "Post" : "Comment";
  if (!validId(req.params.id)) return res.status(404).json({ message: `${label} not found` });
  const { status, moderationNote = "" } = req.body;
  if (!["published", "hidden"].includes(status) || typeof moderationNote !== "string" || moderationNote.length > 500) {
    return res.status(400).json({ message: "Invalid moderation action" });
  }
  const note = moderationNote.trim();
  if (status === "hidden" && !note) return res.status(400).json({ message: "A moderation note is required when hiding content" });

  const Model = targetType === "post" ? CommunityPost : CommunityComment;
  const current = await Model.findById(req.params.id);
  if (!current) return res.status(404).json({ message: `${label} not found` });
  const fromStatus = current.status;
  const postId = targetType === "post" ? current._id : current.post;

  if (fromStatus !== status) {
    const updated = await Model.updateOne({ _id: current._id, status: fromStatus }, { status, moderationNote: note, moderatedBy: req.user._id });
    if (updated.modifiedCount !== 1) return res.status(409).json({ message: "This content was just moderated by someone else. Reload and try again." });
    if (targetType === "comment") {
      if (status === "hidden") await CommunityPost.updateOne({ _id: postId, commentCount: { $gt: 0 } }, { $inc: { commentCount: -1 } });
      else await CommunityPost.updateOne({ _id: postId }, { $inc: { commentCount: 1 } });
    }
  } else {
    await Model.updateOne({ _id: current._id }, { moderationNote: note, moderatedBy: req.user._id });
  }

  // Hiding upholds the reports; keeping content published dismisses them.
  const closed = await CommunityReport.updateMany(
    { targetType, target: current._id, status: "open" },
    { status: status === "hidden" ? "resolved" : "dismissed", reviewedBy: req.user._id, reviewedAt: new Date() }
  );
  await Model.updateOne({ _id: current._id }, { reportCount: 0 });

  await CommunityModerationLog.create({
    actor: req.user._id, targetType, target: current._id, post: postId, subject: current.author,
    fromStatus, toStatus: status, note, reportsClosed: closed.modifiedCount,
  });

  if (fromStatus !== status && status === "hidden") {
    await Notification.create({
      user: current.author,
      title: targetType === "post" ? "تم إخفاء موضوعك في المجتمع" : "تم إخفاء تعليقك في المجتمع",
      message: `أخفى فريق الإشراف ${targetType === "post" ? "موضوعك" : "تعليقك"} لمخالفته إرشادات المجتمع. السبب: ${note}`,
      type: "warning",
      link: "/student/community",
    });
  }

  res.json(await Model.findById(current._id).populate("moderatedBy", "name").lean());
}

const moderatePost = asyncHandler((req, res) => moderate(req, res, "post"));
const moderateComment = asyncHandler((req, res) => moderate(req, res, "comment"));

module.exports = {
  getOverviewAdmin: asyncHandler(async (req, res) => {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const [publishedPosts, activeStories, openReports, recentActivity] = await Promise.all([
      CommunityPost.countDocuments({ status: 'published' }),
      require('../models/Stories').Story.countDocuments({ expiresAt: { $gt: new Date() } }),
      CommunityReport.countDocuments({ status: 'open' }),
      CommunityModerationLog.countDocuments({ createdAt: { $gte: since } }),
    ]);
    res.json({ publishedPosts, activeStories, openReports, recentActivity });
  }),
  getPostImage, setReaction, editOwnPost, editOwnComment,
  getMyStatus, listPosts, createPost, getPost, deleteOwnPost, createComment, deleteOwnComment, reportPost, reportComment,
  listPostsAdmin, getPostAdmin, listReportsAdmin, listModerationLogAdmin, moderatePost, moderateComment,
  listSuspensionsAdmin, suspendUser, liftSuspension, getSettingsAdmin, updateSettingsAdmin,
};
