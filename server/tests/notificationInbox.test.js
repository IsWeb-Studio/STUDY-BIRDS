const { test, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const Notification = require("../src/models/Notification");
const controller = require("../src/controllers/notificationInboxController");

const id = "64b000000000000000000001";
function response() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

beforeEach(() => {
  Notification.findOneAndUpdate = (query, update, options) => {
    assert.deepEqual(query, { _id: id, user: "owner-1" });
    assert.deepEqual(update, { $set: { isRead: true } });
    assert.equal(options.new, true);
    return { lean: () => Promise.resolve({ _id: id, user: "owner-1", isRead: true }) };
  };
  Notification.updateMany = async (query, update) => {
    assert.deepEqual(query, { user: "owner-1", isRead: false });
    assert.deepEqual(update, { $set: { isRead: true } });
    return { modifiedCount: 3 };
  };
});

test("mark-read only updates a notification owned by the signed-in account", async () => {
  const res = response();
  await controller.markNotificationRead({ params: { id }, user: { _id: "owner-1" } }, res, (error) => { throw error; });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.isRead, true);
});

test("mark-read returns not-found for malformed or non-owned notifications", async () => {
  const invalid = response();
  await controller.markNotificationRead({ params: { id: "not-an-id" }, user: { _id: "owner-1" } }, invalid, (error) => { throw error; });
  assert.equal(invalid.statusCode, 404);
  Notification.findOneAndUpdate = () => ({ lean: () => Promise.resolve(null) });
  const missing = response();
  await controller.markNotificationRead({ params: { id }, user: { _id: "owner-1" } }, missing, (error) => { throw error; });
  assert.equal(missing.statusCode, 404);
});

test("mark-all only changes unread notifications belonging to the signed-in account", async () => {
  const res = response();
  await controller.markAllNotificationsRead({ user: { _id: "owner-1" } }, res, (error) => { throw error; });
  assert.deepEqual(res.body, { updated: 3 });
});

test("role-neutral inbox write routes require authentication", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const routes = fs.readFileSync(path.join(__dirname, "../src/routes/contentRoutes.js"), "utf8");
  assert.match(routes, /router\.patch\(["']\/notifications\/read-all["'],\s*protect,/);
  assert.match(routes, /router\.patch\(["']\/notifications\/:id\/read["'],\s*protect,/);
});
