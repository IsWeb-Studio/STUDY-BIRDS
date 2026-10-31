const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      required: true,
    },
    type: {
      type: String,
      enum: ["info", "success", "warning"],
      default: "info",
    },
    link: String,
    category: { type: String, enum: require('../utils/notificationPreferences').categories },
    // Present only for admin announcements. Prevents a retried request from
    // inserting the same announcement twice for the same account.
    broadcastId: { type: String, select: false },
    reminderApplication: { type: mongoose.Schema.Types.ObjectId, ref: "Application" },
    reminderDueAt: Date,
    isRead: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

notificationSchema.index(
  { broadcastId: 1, user: 1 },
  { unique: true, partialFilterExpression: { broadcastId: { $exists: true } } }
);

// Push send-on-create: post('save') runs on every save, but a document's
// isNew flag has already flipped to false by then, so a pre('save') hook
// stashes it in $locals for the post hook to read. Never blocks or fails
// the notification write itself — push delivery is best-effort.
notificationSchema.pre("save", function captureIsNew(next) {
  this.$locals.wasNew = this.isNew;
  next();
});
notificationSchema.post("save", function sendPush(doc) {
  if (!doc.$locals.wasNew || doc.$locals.deferPush) return;
  notificationSchema.statics.dispatchPush(doc).catch(error => console.error('[Push] send failed:', error.message));
});
notificationSchema.statics.dispatchPush = async function dispatchPush(doc) {
  const { sendPushToUser, isPushEnabled } = require("../utils/pushNotifications");
  if (!isPushEnabled()) {
    console.log(`[Push] skipped — env vars not set (notif: ${doc._id}, user: ${doc.user})`);
    return;
  }
  if (doc.category) {
    const user = await require('./User').findById(doc.user).select('isActive notificationPreferences').lean();
    if (!user || user.isActive === false || user.notificationPreferences?.[doc.category] === false) return;
  }
  return sendPushToUser(doc.user, { title: doc.title, body: doc.message, link: doc.link, category: doc.category, notificationId: String(doc._id) });
};

module.exports = mongoose.model("Notification", notificationSchema);
