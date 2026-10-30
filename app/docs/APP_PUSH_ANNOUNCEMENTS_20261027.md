# General mobile push announcements

Implemented in the canonical backend at `D:\work\studybirds_web\server`, web client at `D:\work\studybirds_web\client`, and this Flutter app. No deployment or real broadcast was performed.

## Administrator workflow

- Web: Admin → Student notifications → Mobile app announcement.
- Mobile: Admin dashboard → Student notifications → campaign icon → App announcements.
- Enter a title (80 UTF-16 units maximum) and body (1000 maximum), preview, then explicitly confirm sending to all eligible mobile subscribers.
- Recent history records pending, accepted, no subscribers, and uncertain requests. Accepted means the provider accepted the request, not that every phone received it. Inspect the provider ID in OneSignal for actual delivery metrics.
- Retry an uncertain announcement using its existing history entry or unchanged draft. The server persists the campaign and derives a stable provider idempotency UUID, including across administrators and concurrent retries. Retries expire after 24 hours, inside OneSignal's 30-day deduplication period. There is no automatic resend worker.
- Only authenticated, active `admin` accounts may read or send campaigns. Employees with access to the notification history cannot broadcast. Sends are rate limited to 20 HTTP attempts per IP per hour.

## Audience and preferences

The provider targets Android and iOS push subscriptions across all account roles, without the old helper's 2000-account truncation. OS permission and the app's push consent/login gate remain required. Uninstalled, opted-out, logged-out, offline, or invalid devices cannot be guaranteed delivery. Tapping opens the app; this feature does not create a separate item in each account's in-app inbox.

Announcement audience uses a OneSignal tag filter: missing `sb_app_announcements` (legacy eligible subscriber) OR value `true`. A value `false` excludes the account. The updated app syncs this tag when enabling delivery and after changing/loading notification preferences. Preferences are saved per account through authenticated GET/PUT `/api/mobile-security/notification-preferences`. Existing local preferences are preserved on first initialization. Provider tag propagation is asynchronous; verify on real devices.

Older app versions have not synchronized their existing local announcement preference. Publish this mobile update and have those users open it before relying on migration of that choice. An OS-level push opt-out still applies independently to every send.

## Deployment required — user handles Render

1. Deploy the backend and web client from `D:\work\studybirds_web` to their existing Render services. Include the new model/routes and the User notificationPreferences schema change. MongoDB creates the new campaign collection/index; there is no destructive data migration.
2. On the backend configure `ONESIGNAL_APP_ID` and `ONESIGNAL_REST_API_KEY` for the same OneSignal app used by Flutter. Flutter currently uses app ID `06774f8d-4fc5-427e-b024-ae8fec0114eb`. Keep the REST API key server-only. The local server environment checked during this task has neither complete push configuration nor a verified production setup.
3. Verify Android FCM and iOS APNs credentials in that OneSignal app. Production credentials were not inspected or changed.
4. Publish an updated mobile build for the admin composer and announcement preference synchronization. Existing consenting/subscribed app installations can receive generic broadcasts even before updating, subject to the legacy preference limitation above.
5. Test on designated Android/iPhone accounts with app open, backgrounded, closed, permission denied, announcements disabled, and logout/account switch. A real broadcast from this page targets the whole eligible audience; use a separate staging OneSignal app/build for isolated end-to-end tests.

## Validation

Isolated MongoDB/server tests mock all provider calls: authentication/roles, payload limits, missing credentials, preference ownership/validation, mobile audience/opt-out filter, provider rejection/timeout, stable retry keys, other-admin history retries, concurrent requests and stale retry expiry. Flutter/widget and React tests verify explicit confirmation, cancellation, unchanged retry identity, disabled service and non-admin UI. Flutter analysis and web production compilation are also checked. No actual delivery/device certification is claimed.

Primary provider references: [Push notification API](https://documentation.onesignal.com/reference/push-notification), [audience filters and targeting](https://documentation.onesignal.com/reference/create-message), [subscribed-only segment delivery](https://documentation.onesignal.com/docs/en/segmentation).
