const mongoose = require('mongoose');
module.exports = mongoose.model('StripePaymentReceipt', new mongoose.Schema({
  _id: String, eventId: String, invoice: mongoose.Schema.Types.ObjectId, student: mongoose.Schema.Types.ObjectId,
  amountMinor: Number, currency: String,
  state: { type: String, enum: ['applied', 'reconciliation'], required: true }, reason: String,
}, { timestamps: true }));
