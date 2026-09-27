// #35-43: Independent service request lifecycle
// Student submits a request for a named service → employee assigned → in-progress → completed
const mongoose = require('mongoose');

const SERVICE_STATUSES = ['pending', 'assigned', 'in-progress', 'completed', 'cancelled'];

const serviceRequestSchema = new mongoose.Schema({
  student:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  service:    { type: mongoose.Schema.Types.ObjectId, ref: 'OurService', required: true },
  serviceTitle: { type: String, required: true, trim: true }, // snapshot at submission time
  status:     { type: String, enum: SERVICE_STATUSES, default: 'pending', index: true },
  assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  notes:      { type: String, trim: true, maxlength: 2000, default: '' }, // student's initial note
  staffNote:  { type: String, trim: true, maxlength: 2000, default: '' }, // internal staff note
  invoice:    { type: mongoose.Schema.Types.ObjectId, ref: 'Invoice', default: null },
  statusHistory: [{
    status:    { type: String },
    changedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    changedAt: { type: Date, default: Date.now },
    note:      { type: String, default: '' },
  }],
}, { timestamps: true });

serviceRequestSchema.index({ student: 1, createdAt: -1 });
serviceRequestSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('ServiceRequest', serviceRequestSchema);
module.exports.SERVICE_STATUSES = SERVICE_STATUSES;
