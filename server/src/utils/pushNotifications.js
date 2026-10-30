// Sends push notifications via OneSignal REST API.
// No-op until ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY are set — same
// "ship it inert" pattern used elsewhere in this codebase.
// The mobile app sets externalUserId = MongoDB _id via OneSignal SDK,
// so we address notifications by that ID directly — no token storage needed.

function isPushEnabled() {
  return Boolean(process.env.ONESIGNAL_APP_ID && process.env.ONESIGNAL_REST_API_KEY);
}

// buttons: [{ id, text, url? }]  — OneSignal action buttons (Android/iOS)
async function sendPushToUser(userId, { title, body, link, buttons = [] }) {
  if (!isPushEnabled()) return { sent: 0, disabled: true };

  const payload = {
    app_id: process.env.ONESIGNAL_APP_ID,
    include_aliases: { external_id: [String(userId)] },
    target_channel: 'push',
    headings: { en: title, ar: title },
    contents: { en: body, ar: body },
    data: { screen: link || '', link: link || '' },
    ios_sound: 'default',
    android_sound: 'default',
    priority: 10,
  };
  if (Array.isArray(buttons) && buttons.length > 0) {
    payload.buttons = buttons.slice(0, 3).map(b => ({ id: String(b.id), text: String(b.text), ...(b.url ? { url: String(b.url) } : {}) }));
  }

  try {
    const res = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(payload),
    });
    const json = await res.json();
    if (!res.ok) {
      console.error('[Push] OneSignal error:', JSON.stringify(json));
      return { sent: 0 };
    }
    return { sent: json.recipients ?? 1 };
  } catch (err) {
    console.error('[Push] Failed to send push:', err.message);
    return { sent: 0 };
  }
}

// Broadcast to multiple user IDs in one OneSignal call (max 2000)
async function sendPushToUsers(userIds, notification) {
  if (!isPushEnabled() || !userIds.length) return { sent: 0, disabled: !isPushEnabled() };
  const ids = [...new Set(userIds.map(String))].slice(0, 2000);
  const { title, body, link, buttons = [] } = notification;
  const payload = {
    app_id: process.env.ONESIGNAL_APP_ID,
    include_aliases: { external_id: ids },
    target_channel: 'push',
    headings: { en: title, ar: title },
    contents: { en: body, ar: body },
    data: { screen: link || '', link: link || '' },
    ios_sound: 'default',
    android_sound: 'default',
    priority: 10,
  };
  if (Array.isArray(buttons) && buttons.length > 0) {
    payload.buttons = buttons.slice(0, 3).map(b => ({ id: String(b.id), text: String(b.text), ...(b.url ? { url: String(b.url) } : {}) }));
  }
  try {
    const res = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Key ${process.env.ONESIGNAL_REST_API_KEY}` },
      body: JSON.stringify(payload),
    });
    const json = await res.json();
    if (!res.ok) { console.error('[Push] OneSignal error:', JSON.stringify(json)); return { sent: 0, confirmed: false }; }
    const reportedRecipients = json.recipients;
    const confirmed = Number.isInteger(reportedRecipients) && reportedRecipients >= 0;
    return { sent: confirmed ? reportedRecipients : 0, confirmed };
  } catch (err) {
    console.error('[Push] Failed to broadcast push:', err.message);
    return { sent: 0, confirmed: false };
  }
}

async function sendPushAnnouncement(announcement) {
  if (!isPushEnabled()) throw new Error('Push is disabled');
  // A server-derived UUID isolates two administrators using the same client ID.
  const crypto = require('node:crypto');
  const bytes = crypto.createHash('sha256').update(`announcement:${announcement._id}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const h = bytes.toString('hex');
  const idempotencyKey = `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    signal: AbortSignal.timeout(20000),
    headers: { 'Content-Type': 'application/json', Authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}` },
    body: JSON.stringify({
      app_id: process.env.ONESIGNAL_APP_ID,
      target_channel: 'push',
      filters: [
        { field: 'tag', key: 'sb_app_announcements', relation: 'not_exists' },
        { operator: 'OR' },
        { field: 'tag', key: 'sb_app_announcements', relation: '=', value: 'true' },
      ],
      isAndroid: true, isIos: true,
      headings: { en: announcement.title, ar: announcement.title },
      contents: { en: announcement.body, ar: announcement.body },
      data: { announcementId: String(announcement._id) },
      ios_sound: 'default', idempotency_key: idempotencyKey,
    }),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(`Push provider rejected the request (HTTP ${response.status})`);
  if (typeof result.id === 'string' && result.id) return { status: 'accepted', providerId: result.id };
  // Only a known empty audience is a definitive non-send. Other errors remain
  // uncertain and can be retried with the same provider key.
  if (result.recipients === 0 || (!result.id && Array.isArray(result.errors) && result.errors.length && result.errors.every(error => typeof error === 'string' && /not subscribed|no subscribed|no recipients/i.test(error)))) {
    return { status: 'no_subscribers', providerId: '' };
  }
  throw new Error('Push provider did not confirm acceptance');
}

module.exports = { sendPushToUser, sendPushToUsers, isPushEnabled, sendPushAnnouncement };
