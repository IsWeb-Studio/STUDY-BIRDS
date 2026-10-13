# Push notifications — 23 September 2026

Local implementation; no Firebase project connected and no production push sent.

## Implemented

- `PushToken` stores one row per device token (FCM tokens are device-scoped, not account-scoped); registering an already-known token just reassigns it to whoever is currently logged in on that device.
- `POST /api/push-tokens` registers/updates the current device's token; `DELETE /api/push-tokens` removes it (call on logout); `GET /api/push-tokens/status` reports whether sending is currently enabled.
- Every `Notification.create(...)` in the codebase now also attempts a push send, via a `post('save')` hook on the `Notification` model — no controller call sites needed changing. Send failures are logged and never fail or roll back the notification write itself.
- Sending is a no-op everywhere until `FIREBASE_SERVICE_ACCOUNT_JSON` is set — same "ship it inert" pattern already used for the AI assistant and consultation reminders in this codebase.

## Deployment dependencies

1. Create a Firebase project and a service account with the Cloud Messaging API enabled.
2. Set `FIREBASE_SERVICE_ACCOUNT_JSON` in the server environment to that service account's full JSON key (as a single-line string). Sending activates automatically once this is set — no redeploy-time code change needed.
3. Expired/invalid tokens are pruned automatically from failed send responses; no separate cleanup job is required.
4. **The mobile app does not register a device token yet.** This batch is server infrastructure only: the Flutter app needs the `firebase_messaging` package, platform config files (`google-services.json` / `GoogleService-Info.plist`), and a call to `POST /api/push-tokens` after obtaining its FCM token — that is separate, not-yet-done work.
5. The website does not register for web push either (no VAPID key configured); `platform: "web"` exists in the schema for when that's wanted, but nothing calls it today.

## Tests and limits

`server/tests/pushNotifications.test.js` covers token registration/reassignment, deletion scoped to the owning user, input validation, the `/status` endpoint, and that `sendPushToUser` is a safe no-op when disabled. No test contacts real Firebase infrastructure or sends a real push.

This closes the **send-side** half of PRD items 48/100 (push infrastructure + automatic delivery for every existing internal notification) once Firebase is configured. It does not include: user-configurable notification preferences (item 48's "تحكم المستخدم في تفضيلات الإشعارات"), rich action buttons inside the push payload, or the mobile/web client registration work in point 4 above.
