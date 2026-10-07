// #35-43: Independent service request lifecycle
// Student submits a request for a named service → employee assigned → in-progress → completed
const mongoose = require('mongoose');

const SERVICE_STATUSES = ['pending', 'assigned', 'in-progress', 'en-route', 'completed', 'cancelled'];

const serviceRequestSchema = new mongoose.Schema({
  student:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  service:    { type: mongoose.Schema.Types.ObjectId, ref: 'OurService', required: true },
  serviceTitle: { type: String, required: true, trim: true }, // snapshot at submission time
  status:     { type: String, enum: SERVICE_STATUSES, default: 'pending', index: true },
  assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  notes:      { type: String, trim: true, maxlength: 2000, default: '' },
  staffNote:  { type: String, trim: true, maxlength: 2000, default: '' },
  // #114: price/duration snapshot from OurService at submission time
  price:       { type: Number, min: 0, default: 0 },
  durationDays:{ type: Number, min: 0, default: 0 },
  // #36: documents attached to the request (uploaded by student or staff)
  documents: [{
    fileName: { type: String },
    filePath: { type: String },
    mimeType: { type: String },
    size:     { type: Number },
    uploadedAt: { type: Date, default: Date.now },
  }],
  // #PRD-56: driver tracking detail for transport-type services
  driverDetails: {
    name:          { type: String, trim: true, maxlength: 120, default: '' },
    phone:         { type: String, trim: true, maxlength: 30,  default: '' },
    vehicleType:   { type: String, trim: true, maxlength: 60,  default: '' },
    vehicleNumber: { type: String, trim: true, maxlength: 30,  default: '' },
    etaMinutes:    { type: Number, min: 0, default: null },
    updatedAt:     { type: Date, default: null },
  },
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
