const mongoose = require('mongoose');
module.exports = mongoose.model('FinancialOutbox', new mongoose.Schema({
  _id: String, user: { type: mongoose.Schema.Types.ObjectId, required: true },
  notificationId: { type: mongoose.Schema.Types.ObjectId, default: () => new mongoose.Types.ObjectId() },
  title: String, message: String, link: String, advancePayment: { type: Boolean, default: false },
  done: { type: Boolean, default: false, index: true },
}, { timestamps: true }));
