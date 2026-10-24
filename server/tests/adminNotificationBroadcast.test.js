const { test, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

const User = require("../src/models/User");
const Notification = require("../src/models/Notification");
const NotificationPreference = require("../src/models/NotificationPreference");
const push = require("../src/utils/pushNotifications");
const allAccounts = Array.from({ length: 6 }, (_, index) => ({ _id: `account-${index}` }));
let inserted;
let sentBatches;
let optedOut;
let exists;
let pushConfigured;
let controller;

function response() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
    set() { return this; },
  };
}

beforeEach(() => {
  inserted = [];
  sentBatches = [];
  optedOut = ["account-1"];
  exists = false;
  pushConfigured = true;
  User.find = (filter) => {
    assert.deepEqual(filter, { isActive: { $ne: false } });
    return { select: (fields) => {
      assert.equal(fields, "_id");
      return { lean: async () => allAccounts };
    } };
  };
  NotificationPreference.find = (filter) => {
    assert.deepEqual(filter, { announcements: false });
    return { distinct: async (field) => { assert.equal(field, "user"); return optedOut; } };
  };
  Notification.exists = async (filter) => { assert.equal(typeof filter.broadcastId, "string"); return exists; };
  Notification.insertMany = async (rows, options) => {
    assert.equal(options.ordered, true);
    inserted.push(...rows);
    return rows;
  };
  push.isPushEnabled = () => pushConfigured;
  push.sendPushToUsers = async (ids, announcement) => {
    sentBatches.push({ ids, announcement });
    return { sent: ids.length, confirmed: true };
  };
  delete require.cache[require.resolve("../src/controllers/adminNotificationBroadcastController")];
  controller = require("../src/controllers/adminNotificationBroadcastController");
});

test("announcement stores one in-app notification per active account and sends batched push respecting announcement opt-outs", async () => {
  const res = response();
  await controller.sendAnnouncement({
    body: { title: "  New scholarship  ", message: "  Applications open now.  " },
    user: { _id: "admin-a" },
    get: (name) => name === "Idempotency-Key" ? "request-key-12345678" : undefined,
  }, res, (error) => { throw error; });

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.recipientCount, 6);
  assert.equal(res.body.pushEligibleCount, 5);
  assert.equal(res.body.pushReportedRecipientCount, 5);
  assert.equal(res.body.pushConfigured, true);
  assert.equal(inserted.length, 6);
  assert.ok(inserted.every((row) => row.title === "New scholarship" && row.message === "Applications open now."));
  assert.ok(inserted.every((row) => row.broadcastId === inserted[0].broadcastId));
  assert.equal(sentBatches.length, 1);
  assert.equal(sentBatches[0].ids.length, 5);
  assert.equal(sentBatches[0].announcement.link, "/student/notifications");
  assert.ok(!sentBatches[0].ids.includes("account-1"));
});

test("announcement push is bounded to OneSignal's maximum request size", async () => {
  const accounts = Array.from({ length: 2003 }, (_, index) => ({ _id: `account-${index}` }));
  User.find = () => ({ select: () => ({ lean: async () => accounts }) });
  optedOut = [];
  const res = response();
  await controller.sendAnnouncement({
    body: { title: "Notice", message: "Body" },
    user: { _id: "admin-a" },
    get: () => "request-key-20000001",
  }, res, (error) => { throw error; });
  assert.equal(res.statusCode, 201);
  assert.deepEqual(sentBatches.map((batch) => batch.ids.length), [2000, 3]);
  assert.equal(res.body.pushReportedRecipientCount, 2003);
});

test("in-app announcements are still saved when OneSignal is not configured", async () => {
  pushConfigured = false;
  const res = response();
  await controller.sendAnnouncement({
    body: { title: "Notice", message: "Inbox delivery remains available." },
    user: { _id: "admin-a" },
    get: () => "request-key-no-push-01",
  }, res, (error) => { throw error; });
  assert.equal(res.statusCode, 201);
  assert.equal(res.body.recipientCount, 6);
  assert.equal(res.body.pushConfigured, false);
  assert.equal(inserted.length, 6);
  assert.equal(sentBatches.length, 0);
});

test("invalid, missing-idempotency, and already-recorded broadcasts fail closed without sending", async () => {
  let res = response();
  await controller.sendAnnouncement({ body: { title: " ", message: "Body" }, user: { _id: "admin-a" }, get: () => "request-key-12345678" }, res, (error) => { throw error; });
  assert.equal(res.statusCode, 400);
  assert.equal(inserted.length, 0);
  assert.equal(sentBatches.length, 0);

  res = response();
  await controller.sendAnnouncement({ body: { title: "Notice", message: "Body" }, user: { _id: "admin-a" }, get: () => undefined }, res, (error) => { throw error; });
  assert.equal(res.statusCode, 400);

  exists = true;
  res = response();
  await controller.sendAnnouncement({ body: { title: "Notice", message: "Body" }, user: { _id: "admin-a" }, get: () => "request-key-12345678" }, res, (error) => { throw error; });
  assert.equal(res.statusCode, 409);
  assert.equal(inserted.length, 0);
  assert.equal(sentBatches.length, 0);
});

test("audience preview counts every active account but excludes announcement opt-outs from push", async () => {
  const res = response();
  await controller.getNotificationAudience({ user: { role: "admin" } }, res, (error) => { throw error; });
  assert.deepEqual(res.body, { activeUsers: 6, pushEligibleUsers: 5, pushConfigured: true, canBroadcast: true });
});

test("server-backed notification preferences default to enabled for all supported categories", () => {
  for (const category of NotificationPreference.categories) {
    assert.equal(NotificationPreference.schema.path(category).defaultValue, true);
  }
  assert.ok(NotificationPreference.categories.includes("announcements"));
});
