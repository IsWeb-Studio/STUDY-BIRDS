const { test, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const push = require("../src/utils/pushNotifications");

const originalFetch = global.fetch;
const originalAppId = process.env.ONESIGNAL_APP_ID;
const originalApiKey = process.env.ONESIGNAL_REST_API_KEY;

afterEach(() => {
  global.fetch = originalFetch;
  if (originalAppId === undefined) delete process.env.ONESIGNAL_APP_ID;
  else process.env.ONESIGNAL_APP_ID = originalAppId;
  if (originalApiKey === undefined) delete process.env.ONESIGNAL_REST_API_KEY;
  else process.env.ONESIGNAL_REST_API_KEY = originalApiKey;
});

test("bulk push uses account aliases and reports only the recipient count OneSignal returns", async () => {
  process.env.ONESIGNAL_APP_ID = "synthetic-app-id";
  process.env.ONESIGNAL_REST_API_KEY = "synthetic-api-key";
  let request;
  global.fetch = async (url, options) => {
    request = { url, options };
    return { ok: true, json: async () => ({ recipients: 2 }) };
  };

  const result = await push.sendPushToUsers(["account-1", "account-2"], {
    title: "News",
    body: "A new scholarship is available.",
    link: "/student/notifications",
  });

  assert.equal(request.url, "https://api.onesignal.com/notifications");
  assert.deepEqual(JSON.parse(request.options.body).include_aliases, {
    external_id: ["account-1", "account-2"],
  });
  assert.deepEqual(result, { sent: 2, confirmed: true });
});

test("bulk push does not estimate recipients when OneSignal omits its count", async () => {
  process.env.ONESIGNAL_APP_ID = "synthetic-app-id";
  process.env.ONESIGNAL_REST_API_KEY = "synthetic-api-key";
  global.fetch = async () => ({ ok: true, json: async () => ({ id: "request-id" }) });

  const result = await push.sendPushToUsers(["account-1"], {
    title: "News",
    body: "Message",
  });

  assert.deepEqual(result, { sent: 0, confirmed: false });
});
