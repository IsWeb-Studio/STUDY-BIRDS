// #55-57: Alumni network — lets graduated students create a public profile
// visible to other students for mentoring/networking.
const mongoose = require('mongoose');

const alumniProfileSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true, index: true },
  graduationYear: { type: Number },
  university: { type: String, trim: true },
  country: { type: String, trim: true },
  fieldOfStudy: { type: String, trim: true },
  currentJob: { type: String, trim: true },
  bio: { type: String, trim: true, maxlength: 1000 },
  linkedinUrl: { type: String, trim: true },
  openToMentoring: { type: Boolean, default: false },
  isPublic: { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.model('AlumniProfile', alumniProfileSchema);
