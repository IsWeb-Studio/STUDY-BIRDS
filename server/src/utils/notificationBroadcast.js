const crypto = require("node:crypto");

const TITLE_MAX_LENGTH = 120;
const MESSAGE_MAX_LENGTH = 500;
const NOTIFICATION_BATCH_SIZE = 500;
const PUSH_BATCH_SIZE = 2000;

function normalizeAnnouncement(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return { error: "Enter an announcement title and message." };
  }
  if (typeof input.title !== "string" || typeof input.message !== "string") {
    return { error: "Enter an announcement title and message." };
  }
  const title = input.title.trim();
  const message = input.message.trim();
  if (!title || !message) return { error: "Both title and message are required." };
  if (title.length > TITLE_MAX_LENGTH || message.length > MESSAGE_MAX_LENGTH) {
    return { error: `Title must be at most ${TITLE_MAX_LENGTH} characters and message at most ${MESSAGE_MAX_LENGTH}.` };
  }
  return { value: { title, message } };
}

function splitIntoBatches(values, batchSize) {
  const batches = [];
  for (let index = 0; index < values.length; index += batchSize) {
    batches.push(values.slice(index, index + batchSize));
  }
  return batches;
}

function broadcastIdFor(adminId, idempotencyKey) {
  return crypto.createHash("sha256").update(`${adminId}:${idempotencyKey}`).digest("hex");
}

function buildNotificationRows(users, announcement, broadcastId) {
  return users.map((user) => ({
    user: user._id,
    title: announcement.title,
    message: announcement.message,
    type: "info",
    broadcastId,
  }));
}

module.exports = {
  TITLE_MAX_LENGTH,
  MESSAGE_MAX_LENGTH,
  NOTIFICATION_BATCH_SIZE,
  PUSH_BATCH_SIZE,
  normalizeAnnouncement,
  splitIntoBatches,
  broadcastIdFor,
  buildNotificationRows,
};
