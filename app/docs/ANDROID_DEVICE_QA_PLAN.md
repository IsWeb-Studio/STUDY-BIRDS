# Android real-device QA plan ? isolated environment only

Status: NOT RUN; isolation gates below are incomplete. Existing Phase 4 APK uses the default hosted API and MUST NOT be installed for this isolated QA campaign. Compilation success is historical evidence, not device QA. No device, provider or database access occurred in Phase 5.

## Isolation gates before install

1. Recover disk capacity only after explicit cleanup approval. Target at least 6 GiB free on D before the next debug build (engineering budget, not a proven minimum); keep additional margin and monitor space. No build until capacity is sufficient.
2. Provision a dedicated local/QA backend instance, distinct MONGODB_URI/database, synthetic students/employees, separate JWT secrets and separate uploads/storage. Never copy production .env, tokens, real passports, signing keys or user data. Bind local backend to loopback; use an owner-reviewed QA env outside source. Confirm target and database identity from local configuration without printing secrets. Do not start the current server using an unknown existing environment.
3. Route the Android device to a controlled HTTPS QA API, for example an explicitly provisioned QA host, with valid TLS. API_BASE_URL is supported by lib/core/network/api_client.dart; pass an explicit /api URL and reject any redirect or request toward production. A LAN/USB alternative needs reviewed debug-only transport/TLS setup; do not disable TLS checks or modify release pinning. Verify device DNS and endpoint independently before signing in.
4. Provider isolation is a BLOCKER: PushNotificationService currently has a hard-coded OneSignal app ID and Google has a configured web client ID. API_BASE_URL alone does not isolate them. Prepare a separate scoped QA configuration patch with QA-only provider IDs or disabled/stubbed push/Google for offline auth cases; approve that scope before implementation. Use a QA mail sink for email codes, sandbox SMS/WhatsApp, no outbound real delivery, no production billing. OAuth/push real-provider tests require dedicated QA projects/accounts. Block production egress on device/server; do not send trial calls to determine whether a host is production.
5. Debug Sentry is disabled unless SENTRY_ENABLED=true; keep false. POSTHOG_API_KEY must be empty. SENTRY_ENV=qa does not select a separate Sentry project; release enables the configured DSN, so release QA needs separate telemetry configuration. Inventory all provider/media links in synthetic fixtures and backend responses; permit only QA destinations.
6. Use a spare device or isolated Android user/profile and fresh app data; preserve real app data and never install over a user's production account. Review package ID/signature collision before install, or approve a separate QA application ID/variant. No signing changes are made by this plan.

## Build/install procedure after gates

From D:/work/studybirds_session_release/app, with owner-selected QA host and reviewed provider isolation, run flutter build apk --debug --dart-define=API_BASE_URL=https://<approved-qa-host>/api --dart-define=SENTRY_ENABLED=false --dart-define=SENTRY_ENV=qa --dart-define=POSTHOG_API_KEY=. Placeholder is not executable configuration. Record exact source hashes, Flutter/Android toolchain, defines without secrets, exit/log, APK SHA-256 and free space. Inspect runtime network logs to prove only allowlisted QA hosts are contacted. Install on the isolated profile/device only after verifying that artifact. No build/install executed here.

## Test sequence and expected evidence

- Record Android version/model, Arabic RTL and English, slow/fast network, permissions and app version; include low-memory hardware plus current Android where available.
- Synthetic first login/password setup/email-code verification; deny unverified passwordless access; valid/expired/used codes and logout/expired sessions. QA Google/mobile handoff only after dedicated OAuth setup.
- Switch A?B and back: no prior-account stories, viewer lists, tokens or preference state; late network responses after logout cannot restore private data.
- Story upload progress/cancel/failure; viewer totals/list privacy; deletion immediate feed update, double tap deduplication, server success, simulated 500/offline rollback and retry. Keep existing card design; fullscreen patch 04 remains excluded.
- Per-account notification preferences persist across restart, switch and offline retry; stale save response cannot affect B. Security and urgent notifications remain mandatory. Test denied permission, foreground/background/killed state using QA push credentials only.
- Messages delivery/reconnect/order and duplicate avoidance; passport upload/extraction using fictional samples; admin program create/edit/delete using QA records; support ticket ownership/team assignment; streak three recoveries per month and fourth denial/boundary using QA clock/data only. These are regression acceptance cases, not claims about newly verified implementation.
- Accessibility text scaling, RTL navigation/profile bar, rotation, safe areas, media/audio/camera permissions and offline error messages. Record expected vs actual, redacted screenshots/logs and reproducible failures.

## Exit gate

No unexplained production network requests; all critical flows pass on recorded devices; all failures triaged; backend/app notification contract version matched; remaining 275 infos and development dependency risks reviewed. Signed release, store upgrade, iOS, publication and production-service changes need separate approval and evidence.
