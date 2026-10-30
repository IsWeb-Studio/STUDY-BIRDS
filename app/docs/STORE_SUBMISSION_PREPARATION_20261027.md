# Store submission preparation — 27 October 2026

These are local source changes, not a submission or a guarantee of store approval.
The mobile source is `D:\work\studybirds_app\study_birds_app-main`.
The owner identified the current API and website source as `D:\work\studybirds_web\server` and `D:\work\studybirds_web\client`. Do not build an older sibling Flutter copy for this release.

## Changes

- Android targets at least API 36; camera hardware is optional. Exact alarms are unnecessary because reminders already use inexact scheduling. Microphone and broad external-storage permissions are removed from the merged manifest; file/photo selection uses system pickers and passport capture disables audio.
- OpenCV upgraded from 4.10.0 to 4.13.0 for modern native compatibility. `node tool/check_android_native_alignment.mjs` checks every merged 64-bit native library's ELF LOAD alignment. This does not replace zip-alignment inspection or real-device testing.
- iOS now packages `PrivacyInfo.xcprivacy`, describes the app's broader collected data categories, registers `studybirds://`, and recognizes the official website domains. Removed the inaccurate permission description claiming photo-library access was required for an ICS file.
- Privacy and contact links are available before login and in account/security settings. All account roles reaching Security have a permanent-deletion entry.
- Optional analytics/error reporting is off by default, with an explicit device preference in Account security. PostHog session replay/lifecycle autocapture and Sentry performance/session collection are disabled. Names/emails, raw search terms, invoice IDs and payment amounts are excluded from the analytics wrappers. Revocation stops telemetry; enabling crash reporting takes effect after restart.
- OneSignal requires data consent and remains paused until notification delivery is enabled after OS permission. The explanation identifies OneSignal and the notification data used.
- Both assistant screens request consent before the first message in that screen session. Answers have an in-app report action. Community publishing requires acceptance of community rules; stories also have reporting.
- Server-side user blocks apply to community posts/comments, story reads, direct messaging and friendship/profile access. Account security lists blocks and allows removal. Blocking invalidates cached feeds/inboxes; conversation deletion also clears query-scoped caches and prevents stale replies from restoring them.
- Safety reports enter the existing escalated support queue. Staff must review and act on this queue; creating a report is not automatic content moderation.
- Passwordless account deletion now requires an email code. The API durably records deletion intent and disables access immediately. A worker removes associated data and storage assets, retries outages, preserves anonymized accounting entries, and sends completion email when mail delivery is configured. Completion-notification retries never rescan a newly registered account with the same email.
- Website adds public `/delete-account`, linked from the footer/privacy page. It works without app installation or login, using an email confirmation code. The existing `/account/delete` uses this same flow. Privacy content now covers mobile services, optional telemetry, community rules and deletion.

## Deployment contracts

Deploy and validate the API and website changes together before distributing the mobile build:

- `POST /api/auth/account/verification` (authenticated).
- `DELETE /api/auth/account` with password or emailCode returns HTTP 202 after durable acceptance.
- `POST /api/auth/account-deletion/request` and `/confirm` (public, rate limited).
- `GET /api/safety/blocks`, `PUT`/`DELETE /api/safety/blocks/:id`, `POST /api/safety/reports` (authenticated).
- Start `startDeletionWorker()` after database connection; monitor pending/complete `AccountDeletionJob` records and repeated cleanup errors. These jobs must not silently accumulate.
- Verify SMTP, Cloudinary access/deletion, indexes and support moderation on the actual hosting environment. Test with disposable accounts, including Google/Apple accounts and a simulated storage failure. No production records were deleted during this work.

The supplied server's assistant config currently lacks the mobile app's verified-help protocol. The app deliberately refuses that incompatible service. This work does not replace that protocol or enable the old general-purpose AI endpoint. Align that service before advertising a working assistant in store metadata.

## Owner/platform checks still required

- Publish and check `https://studybirds.net/privacy-policy` and `https://studybirds.net/delete-account`; local source changes do not update the live site.
- Complete Google Play Data safety, account-deletion URL, content rating, target audience, ads declaration and any required closed testing in the actual Play Console. Use the app's actual SDK/data inventory, including optional collection. Do not declare the app child-directed without implementing the corresponding protections.
- Confirm that build number 14 has not already been uploaded to either store; otherwise increment the version/build number and rebuild before uploading.
- Complete App Store privacy labels, age rating, support URL, reviewer credentials and review notes. Verify current Apple SDK/Xcode submission requirements on a Mac, archive/validate the actual build, inspect the aggregated SDK privacy report, and test physical iPhone/iPad behavior.
- Sign in with Apple exists in the app, but Apple token exchange/revocation and private-email relay delivery must be verified against the real Apple developer configuration. The supplied backend does not retain an Apple revocation credential; that provider lifecycle remains a submission blocker for an enabled Apple login. Do not claim it is verified by the generic deletion test.
- Audit historical URL-only uploads, external CRM/university/provider copies and backups. The deletion worker only destroys URL-only cloud assets when their ownership can be demonstrated; it never deletes another person's pasted media URL. Necessary financial retention periods and downstream deletion obligations require the owner's actual operating policy. A local cascade test is not proof of erasure at every external processor.
- Configure Android assetlinks using the **Play app signing** certificate, and Apple's associated-domain file using the real Team ID/bundle ID. Upload-key fingerprints are not a substitute for the Play signing certificate. Test both verified HTTPS links and the custom scheme.
- Perform real-device registration/login/deletion, denied-permission, uploads/OCR, notifications, blocking/reporting, RTL, accessibility and background tests. Test a 16 KB Android device/emulator; ELF alignment alone is insufficient.
- Payments currently represent study-abroad/service invoices. Review any future paid digital features, subscriptions or currency sales separately for the stores' billing requirements; do not route such purchases through the existing external invoice flow by assumption.

## Validation

- Flutter full suite: **572 passed**, zero failures (`flutter test --no-pub --concurrency=2`).
- Final `flutter analyze --no-pub`: **No issues found**.
- Server: six isolated safety/community/messaging tests passed. The deletion test was rerun successfully after the final snapshot-ID hardening; it covers wrong credentials, passwordless verification, blocked contact, storage retry, retained accounting totals and completion-email retry without affecting a replacement account.
- Website deletion flow: two tests passed; final TypeScript/Vite production build passed.
- Android release app bundle built and signature verification returned `jar verified`. Artifact: `build/app/outputs/bundle/release/app-release.aab`, 148,518,530 bytes. SHA-256: `E21C74772AB2CE6685604599354227A5B993AA139535B97FABA46E8642D684E0`.
- Merged release manifest targets API 36 and excludes RECORD_AUDIO, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE and SCHEDULE_EXACT_ALARM. The 22 actual 64-bit shared libraries extracted from the signed AAB all passed the ELF 16 KB alignment check. This is not a 16 KB device-runtime test.
- iOS XML and privacy dictionary key/value structure checked locally. No iOS archive, App Store validation, physical-device pass or production deployment is claimed.

## Policy references consulted

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.android.com/guide/practices/page-sizes
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype
