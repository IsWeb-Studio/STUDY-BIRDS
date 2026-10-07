const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  kind: { type: String, enum: ['offer', 'opportunity'], required: true, index: true },
  title: { type: String, required: true, maxlength: 200 },
  organization: { type: String, maxlength: 200, default: '' },
  country: { type: String, maxlength: 100, default: '' },
  description: { type: String, maxlength: 5000, default: '' },
  terms: { type: String, maxlength: 3000, default: '' },
  url: { type: String, maxlength: 1000, default: '' },
  validFrom: Date,
  expiresAt: Date,
  published: { type: Boolean, default: false },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });
schema.index({ kind: 1, published: 1, createdAt: -1 });
module.exports = mongoose.model('StudentListing', schema);
