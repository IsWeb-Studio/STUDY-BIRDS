// #55-57 + PRD-Community: Alumni network + job/internship postings
const express = require('express');
const { protect, authorize } = require('../middleware/authMiddleware');
const run = require('../utils/asyncHandler');
const AlumniProfile = require('../models/AlumniProfile');
const JobPost = require('../models/JobPost');
const mongoose = require('mongoose');

const JOB_TYPES = ['internship', 'part-time', 'full-time', 'freelance', 'volunteer'];

const router = express.Router();
router.use(protect);

// Public listing — any authenticated user can browse alumni
router.get('/', run(async (req, res) => {
  const filter = { isPublic: true };
  if (req.query.country) {
    if (typeof req.query.country !== 'string' || req.query.country.length > 100) return res.sendStatus(400);
    filter.country = { $regex: req.query.country.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
  }
  if (req.query.mentoring === 'true') filter.openToMentoring = true;
  const rows = await AlumniProfile.find(filter)
    .populate('user', 'name avatar')
    .sort({ createdAt: -1 })
    .limit(100)
    .lean();
  res.json(rows);
}));

// Get a single alumni profile by user id
router.get('/:userId', run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.userId)) return res.sendStatus(404);
  const profile = await AlumniProfile.findOne({ user: req.params.userId, isPublic: true }).populate('user', 'name avatar').lean();
  if (!profile) return res.status(404).json({ message: 'Alumni profile not found' });
  res.json(profile);
}));

// Create or update own alumni profile (students only)
router.put('/me', authorize('student'), run(async (req, res) => {
  const { graduationYear, university, country, fieldOfStudy, currentJob, bio, linkedinUrl, openToMentoring, isPublic } = req.body;
  for (const [key, limit] of Object.entries({ university: 200, country: 100, fieldOfStudy: 200, currentJob: 200, bio: 1000, linkedinUrl: 500 })) {
    if (req.body[key] !== undefined && (typeof req.body[key] !== 'string' || req.body[key].length > limit)) {
      return res.status(400).json({ message: `Invalid profile field: ${key}` });
    }
  }
  if (graduationYear !== undefined && graduationYear !== null &&
      (!Number.isInteger(graduationYear) || graduationYear < 1900 || graduationYear > new Date().getFullYear())) {
    return res.status(400).json({ message: 'سنة التخرج غير صالحة' });
  }
  for (const key of ['isPublic', 'openToMentoring']) {
    if (req.body[key] !== undefined && typeof req.body[key] !== 'boolean') return res.sendStatus(400);
  }
  if (bio && bio.length > 1000) return res.status(400).json({ message: 'Bio must be under 1000 characters' });
  if (linkedinUrl && typeof linkedinUrl === 'string' && linkedinUrl.trim()) {
    try {
      const u = new URL(linkedinUrl);
      if (u.protocol !== 'https:' || !['linkedin.com', 'www.linkedin.com'].includes(u.hostname) || u.username || u.password) return res.status(400).json({ message: 'أدخل رابط LinkedIn صحيحًا وآمنًا' });
    } catch { return res.status(400).json({ message: 'Invalid LinkedIn URL' }); }
  }
  const set = {};
  if (graduationYear !== undefined) set.graduationYear = Number(graduationYear) || null;
  if (university !== undefined) set.university = String(university || '').trim().slice(0, 200);
  if (country !== undefined) set.country = String(country || '').trim().slice(0, 100);
  if (fieldOfStudy !== undefined) set.fieldOfStudy = String(fieldOfStudy || '').trim().slice(0, 200);
  if (currentJob !== undefined) set.currentJob = String(currentJob || '').trim().slice(0, 200);
  if (bio !== undefined) set.bio = String(bio || '').trim();
  if (linkedinUrl !== undefined) set.linkedinUrl = String(linkedinUrl || '').trim();
  if (typeof openToMentoring === 'boolean') set.openToMentoring = openToMentoring;
  if (typeof isPublic === 'boolean') set.isPublic = isPublic;
  const profile = await AlumniProfile.findOneAndUpdate(
    { user: req.user._id },
    { $set: set },
    { upsert: true, new: true, setDefaultsOnInsert: true, runValidators: true }
  ).populate('user', 'name avatar');
  res.json(profile);
}));

// Get own alumni profile
router.get('/me/profile', authorize('student'), run(async (req, res) => {
  const profile = await AlumniProfile.findOne({ user: req.user._id }).populate('user', 'name avatar').lean();
  res.json(profile || null);
}));

// ── Job/Internship Postings ────────────────────────────────────────────────

// List active job posts (any authenticated user)
router.get('/jobs', run(async (req, res) => {
  const filter = { isActive: true, $or: [{ expiresAt: null }, { expiresAt: { $gt: new Date() } }] };
  if (req.query.type && JOB_TYPES.includes(req.query.type)) filter.type = req.query.type;
  if (req.query.location) filter.location = { $regex: String(req.query.location).trim().slice(0, 100).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
  const posts = await JobPost.find(filter).populate('postedBy', 'name').sort({ createdAt: -1 }).limit(100).lean();
  res.json(posts);
}));

// Get a single job post
router.get('/jobs/:id', run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Post not found' });
  const post = await JobPost.findOne({ _id: req.params.id, isActive: true }).populate('postedBy', 'name').lean();
  if (!post) return res.status(404).json({ message: 'Job post not found' });
  res.json(post);
}));

// Create a job post (alumni/student only — must have an alumni profile)
router.post('/jobs', authorize('student'), run(async (req, res) => {
  const hasProfile = await AlumniProfile.exists({ user: req.user._id, isPublic: true });
  if (!hasProfile) return res.status(403).json({ message: 'يجب أن يكون لديك ملف خريج عام لنشر الوظائف' });

  const { title, company = '', location = '', type = 'internship', description = '', requirements = '', contactEmail = '', externalUrl = '', expiresAt = null } = req.body;
  if (typeof title !== 'string' || !title.trim() || title.length > 200) return res.status(400).json({ message: 'عنوان الوظيفة مطلوب' });
  if (!JOB_TYPES.includes(type)) return res.status(400).json({ message: 'نوع الوظيفة غير صالح' });
  if (externalUrl && typeof externalUrl === 'string' && externalUrl.trim()) {
    try { const u = new URL(externalUrl); if (!['http:', 'https:'].includes(u.protocol)) throw new Error(); } catch { return res.status(400).json({ message: 'رابط الوظيفة غير صالح' }); }
  }
  const expires = expiresAt ? new Date(expiresAt) : null;
  if (expires && !Number.isFinite(expires.getTime())) return res.status(400).json({ message: 'تاريخ انتهاء غير صالح' });

  const post = await JobPost.create({
    postedBy: req.user._id,
    title: title.trim(), company: String(company).trim().slice(0, 200),
    location: String(location).trim().slice(0, 200), type,
    description: String(description).trim().slice(0, 3000),
    requirements: String(requirements).trim().slice(0, 2000),
    contactEmail: String(contactEmail).trim().slice(0, 200),
    externalUrl: String(externalUrl).trim().slice(0, 500),
    expiresAt: expires,
  });
  res.status(201).json(post);
}));

// Delete own job post
router.delete('/jobs/:id', authorize('student'), run(async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ message: 'Post not found' });
  const post = await JobPost.findOneAndDelete({ _id: req.params.id, postedBy: req.user._id });
  if (!post) return res.status(404).json({ message: 'وظيفة غير موجودة أو ليست ملكك' });
  res.json({ deleted: true });
}));

module.exports = router;
