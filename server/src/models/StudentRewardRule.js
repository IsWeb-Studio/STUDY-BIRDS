const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  event: {
    type: String,
    enum: [
      'application-submitted',
      'final-admission',
      'referral-qualified',
      // #53: journey milestone events
      'documents-submitted',
      'university-selection',
      'first-payment',
      'visa-approved',
      'studies-started',
    ],
    required: true,
    unique: true,
  },
  title: { type: String, required: true, trim: true, maxlength: 150 },
  points: { type: Number, required: true, min: 1, max: 1000000, validate: Number.isSafeInteger },
  enabled: { type: Boolean, default: false },
}, { timestamps: true });
module.exports = mongoose.model('StudentRewardRule', schema);
