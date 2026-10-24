const Notification = require("../models/Notification");
const NotificationPreference = require("../models/NotificationPreference");
const User = require("../models/User");
const asyncHandler = require("../utils/asyncHandler");
const { isPushEnabled, sendPushToUsers } = require("../utils/pushNotifications");
const {
  NOTIFICATION_BATCH_SIZE,
  PUSH_BATCH_SIZE,
  normalizeAnnouncement,
  splitIntoBatches,
  broadcastIdFor,
  buildNotificationRows,
} = require("../utils/notificationBroadcast");

const getActiveAudience = async () => {
  const [activeUsers, pushDisabledUserIds] = await Promise.all([
    User.find({ isActive: { $ne: false } }).select("_id").lean(),
    NotificationPreference.find({ announcements: false }).distinct("user"),
  ]);
  const pushDisabled = new Set(pushDisabledUserIds.map(String));
  return {
    activeUsers,
    pushEligibleIds: activeUsers.map(({ _id }) => String(_id)).filter((id) => !pushDisabled.has(id)),
  };
};

const getNotificationAudience = asyncHandler(async (req, res) => {
  const audience = await getActiveAudience();
  res.set("Cache-Control", "no-store").json({
    activeUsers: audience.activeUsers.length,
    pushEligibleUsers: audience.pushEligibleIds.length,
    pushConfigured: isPushEnabled(),
    canBroadcast: req.user?.role === "admin",
  });
});

const sendAnnouncement = asyncHandler(async (req, res) => {
  const normalized = normalizeAnnouncement(req.body);
  if (normalized.error) return res.status(400).json({ message: normalized.error });

  const idempotencyKey = req.get("Idempotency-Key");
  if (!idempotencyKey || !/^[A-Za-z0-9_.:-]{8,128}$/.test(idempotencyKey)) {
    return res.status(400).json({ message: "A valid Idempotency-Key is required." });
  }
  const broadcastId = broadcastIdFor(req.user._id, idempotencyKey);
  const alreadyExists = await Notification.exists({ broadcastId });
  if (alreadyExists) {
    return res.status(409).json({
      message: "This announcement request was already recorded. Refresh the notification list before sending another one.",
    });
  }

  const audience = await getActiveAudience();
  if (audience.activeUsers.length === 0) {
    return res.status(409).json({ message: "There are no active user accounts to notify." });
  }

  const rows = buildNotificationRows(audience.activeUsers, normalized.value, broadcastId);
  // insertMany intentionally bypasses Notification's per-document save hook;
  // the OneSignal helper below sends bounded bulk requests instead.
  for (const batch of splitIntoBatches(rows, NOTIFICATION_BATCH_SIZE)) {
    await Notification.insertMany(batch, { ordered: true });
  }

  let pushReportedRecipientCount = 0;
  let pushUnconfirmedBatches = 0;
  const pushConfigured = isPushEnabled();
  if (pushConfigured) {
    for (const batch of splitIntoBatches(audience.pushEligibleIds, PUSH_BATCH_SIZE)) {
      const result = await sendPushToUsers(batch, {
        title: normalized.value.title,
        body: normalized.value.message,
        link: "/student/notifications",
      });
      pushReportedRecipientCount += Number(result.sent) || 0;
      if (!result.confirmed) pushUnconfirmedBatches += 1;
    }
  }

  res.status(201).json({
    recipientCount: audience.activeUsers.length,
    pushEligibleCount: audience.pushEligibleIds.length,
    pushConfigured,
    pushReportedRecipientCount,
    pushUnconfirmedBatches,
  });
});

module.exports = { getNotificationAudience, sendAnnouncement };
