const mongoose = require('mongoose');
const slotSchema = new mongoose.Schema({
  advisor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  startsAt: { type: Date, required: true },
  mode: { type: String, enum: ['online', 'phone', 'office'], required: true },
  meetingUrl: { type: String, default: '' },
  instructions: { type: String, maxlength: 500, default: '' },
  enabled: { type: Boolean, default: true },
  reservation: { type: mongoose.Schema.Types.ObjectId, default: null },
}, { timestamps: true });
// All slots last 30 minutes and start on a UTC half-hour boundary.
slotSchema.index({ advisor: 1, startsAt: 1 }, { unique: true });
slotSchema.index({ enabled: 1, startsAt: 1 });
const outcomeSchema = new mongoose.Schema({
  result: { type: String, enum: ['completed', 'no-show'], required: true },
  summary: { type: String, required: true, maxlength: 2000 },
  nextSteps: { type: String, maxlength: 2000, default: '' },
  recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  recordedAt: { type: Date, required: true },
}, { _id: false });
const bookingSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  advisor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  slot: { type: mongoose.Schema.Types.ObjectId, ref: 'ConsultationSlot', required: true },
  startsAt: { type: Date, required: true },
  status: { type: String, enum: ['booked', 'cancelled', 'completed', 'no-show'], default: 'booked' },
  outcome: outcomeSchema,
  outcomeHistory: [outcomeSchema],
  remindedFor: Date,
  history: [{ action: { type: String, enum: ['booked', 'cancelled', 'rescheduled'] },
    slot: mongoose.Schema.Types.ObjectId, startsAt: Date,
    changedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, changedAt: Date }],
}, { timestamps: true });
bookingSchema.index({ slot: 1 }, { unique: true, partialFilterExpression: { status: 'booked' } });
bookingSchema.index({ student: 1, startsAt: 1 }, { unique: true, partialFilterExpression: { status: 'booked' } });
bookingSchema.index({ status: 1, startsAt: 1 });
module.exports = {
  Slot: mongoose.model('ConsultationSlot', slotSchema),
  Booking: mongoose.model('ConsultationBooking', bookingSchema),
};
