// #PRD-Community: Job/internship postings shared by alumni for students
const mongoose = require('mongoose');

const jobPostSchema = new mongoose.Schema({
  postedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  title: { type: String, required: true, trim: true, maxlength: 200 },
  company: { type: String, trim: true, maxlength: 200, default: '' },
  location: { type: String, trim: true, maxlength: 200, default: '' },
  type: { type: String, enum: ['internship', 'part-time', 'full-time', 'freelance', 'volunteer'], default: 'internship' },
  description: { type: String, trim: true, maxlength: 3000, default: '' },
  requirements: { type: String, trim: true, maxlength: 2000, default: '' },
  contactEmail: { type: String, trim: true, maxlength: 200, default: '' },
  externalUrl: { type: String, trim: true, maxlength: 500, default: '' },
  expiresAt: { type: Date, default: null },
  isActive: { type: Boolean, default: true },
}, { timestamps: true });

jobPostSchema.index({ isActive: 1, createdAt: -1 });
jobPostSchema.index({ type: 1, isActive: 1 });

module.exports = mongoose.model('JobPost', jobPostSchema);
