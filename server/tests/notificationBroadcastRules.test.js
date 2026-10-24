const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  TITLE_MAX_LENGTH,
  MESSAGE_MAX_LENGTH,
  normalizeAnnouncement,
  splitIntoBatches,
  broadcastIdFor,
  buildNotificationRows,
} = require("../src/utils/notificationBroadcast");
const {
  categories,
  defaults,
  shapePreferences,
  validatePreferenceUpdate,
} = require("../src/utils/notificationPreferences");

test("announcement input is trimmed, bounded, and requires both fields", () => {
  assert.deepEqual(normalizeAnnouncement({ title: "  Update  ", message: "  Details  " }), { value: { title: "Update", message: "Details" } });
  assert.ok(normalizeAnnouncement({ title: " ", message: "Details" }).error);
  assert.ok(normalizeAnnouncement({ title: "t".repeat(TITLE_MAX_LENGTH + 1), message: "Body" }).error);
  assert.ok(normalizeAnnouncement({ title: "Title", message: "m".repeat(MESSAGE_MAX_LENGTH + 1) }).error);
  assert.ok(normalizeAnnouncement(null).error);
});

test("broadcast batching is bounded and idempotency identity is deterministic but account scoped", () => {
  assert.deepEqual(splitIntoBatches([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assert.equal(splitIntoBatches([], 2).length, 0);
  const key = broadcastIdFor("admin-a", "request-12345678");
  assert.equal(key, broadcastIdFor("admin-a", "request-12345678"));
  assert.notEqual(key, broadcastIdFor("admin-b", "request-12345678"));
});

test("broadcast notification rows are user scoped and do not carry a role restriction", () => {
  const rows = buildNotificationRows([{ _id: "user-1" }, { _id: "user-2" }], { title: "News", message: "Details" }, "broadcast-1");
  assert.deepEqual(rows, [
    { user: "user-1", title: "News", message: "Details", type: "info", broadcastId: "broadcast-1" },
    { user: "user-2", title: "News", message: "Details", type: "info", broadcastId: "broadcast-1" },
  ]);
});

test("notification preference reads flag first-time sync and validate only known boolean categories", () => {
  assert.deepEqual(shapePreferences(null), { ...defaults, _initialized: false });
  assert.deepEqual(shapePreferences({ announcements: false }), { ...defaults, announcements: false, _initialized: true });
  assert.equal(validatePreferenceUpdate({ announcements: false, community: true }), true);
  assert.equal(validatePreferenceUpdate({ announcements: "false" }), false);
  assert.equal(validatePreferenceUpdate({ security: false }), false);
  assert.equal(validatePreferenceUpdate({}), false);
  assert.ok(categories.includes("announcements"));
});

test("broadcast endpoint is explicitly restricted to the admin role", () => {
  const routes = fs.readFileSync(path.join(__dirname, "../src/routes/adminRoutes.js"), "utf8");
  assert.match(routes, /router\.post\(["']\/student-notifications\/broadcast["'],\s*authorize\(["']admin["']\),\s*adminNotificationBroadcast\.sendAnnouncement\)/);
});
