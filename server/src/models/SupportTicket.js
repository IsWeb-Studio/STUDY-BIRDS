const mongoose = require("mongoose");

const SUPPORT_TICKET_CATEGORIES = [
  "documents",
  "application-status",
  "payment",
  "arrival-services",
  "student-application",
  "commission",
  "technical-issue",
  "other",
];

const supportReplySchema = new mongoose.Schema(
  {
    message: {
      type: String,
      required: true,
      trim: true,
    },
    fromRole: {
      type: String,
      enum: ["student", "partner", "admin"],
      required: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: true }
);

const supportTicketSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      index: true,
    },
    agent: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      index: true,
    },
    requesterRole: {
      type: String,
      enum: ["student", "partner"],
      default: "partner",
      index: true,
    },
    subject: {
      type: String,
      required: true,
      trim: true,
    },
    message: {
      type: String,
      required: true,
      trim: true,
    },
    category: {
      type: String,
      enum: SUPPORT_TICKET_CATEGORIES,
      default: "other",
    },
    status: {
      type: String,
      enum: ["open", "in-progress", "answered", "closed"],
      default: "open",
    },
    // #44: assignment / escalation
    assignedTo:     { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    isEmergency:    { type: Boolean, default: false },
    escalated:      { type: Boolean, default: false },
    escalationNote: { type: String, trim: true, maxlength: 1000, default: '' },
    attachmentStorage: { type: new mongoose.Schema({ publicId: String, resourceType: String, deliveryType: String, format: String }, { _id: false }), select: false },
    attachment: {
      fileName: String,
      filePath: String,
      mimeType: String,
      size: Number,
    },
    // #46: multiple attachments (max 5) in addition to the legacy single attachment
    attachments: [{
      fileName: { type: String },
      filePath: { type: String },
      mimeType: { type: String },
      size:     { type: Number },
    }],
    replies: [supportReplySchema],
  },
  { timestamps: true }
);

module.exports = mongoose.model("SupportTicket", supportTicketSchema);
module.exports.SUPPORT_TICKET_CATEGORIES = SUPPORT_TICKET_CATEGORIES;
