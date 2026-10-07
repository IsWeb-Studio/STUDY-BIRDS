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
    if (!res.ok) { console.error('[Push] OneSignal error:', JSON.stringify(json)); return { sent: 0 }; }
    return { sent: json.recipients ?? ids.length };
  } catch (err) {
    console.error('[Push] Failed to broadcast push:', err.message);
    return { sent: 0 };
  }
}

module.exports = { sendPushToUser, sendPushToUsers, isPushEnabled };
