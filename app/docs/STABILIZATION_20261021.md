# Local stabilization — 21 October 2026

## Scope and preservation

The selected Flutter source remains `D:\work\studybirds_app\study_birds_app-main`; selected backend/website remain the `server` and `client` folders in `D:\work\studybirds_session_release`. No old repository was moved, archived or deleted. No commit, branch change, stash, reset, push, deployment or production database operation was performed.

Before these changes, `.git/stabilization-20261021/app` and `deployment` received SHA-256 verified copies of 539 and 1,160 tracked/untracked files respectively, manifests, binary working-tree/staged patches, HEAD/status records and verified Git history bundles. Earlier private configuration/signing checkpoints remain available. These are local recovery points, not new commits or an off-device backup.

## Concurrent writer investigation

`lib/screens/export.dart` was absent when investigated. A 45-second recursive read-only observation of application Dart/pubspec source saw no write events. No active build was observed; language tooling, editor formatting and other Codex processes existed. This does not identify the source of the earlier transient file and does not rule out a future writer. No unrelated process was terminated and no editor setting was changed.

## Notification policy implemented

The user explicitly confirmed that security and emergency notifications must never be muted by account preferences. Seven optional categories default to enabled: payments, admission, documents, consultations, visa, support and announcements.

- Authenticated GET/PUT `/mobile-security/notification-preferences` reads/writes only the signed-in account; partial updates preserve other categories. Responses are not cacheable. Unknown keys, including attempts to mute security/urgent, are rejected.
- Preferences are stored in the User model. Single/broadcast push delivery consults those preferences; broadcasts still deduplicate recipients. Mandatory/security/urgent notifications bypass optional filtering. Emergency support producers set explicit mandatory metadata. Legacy notifications are classified by destination; unknown notifications remain deliverable rather than being guessed from translated text.
- Flutter displays server-confirmed preferences with account-scoped local cache, save progress, rollback on failed writes, retry on failed reads, and rejection of late responses after session/account changes. Unscoped legacy cache is ignored because its owner cannot be established.
- Scheduled local consultation/payment/document reminders consult the account cache. Disabling a category cancels its queued reminders; loading disabled server categories also cancels those queued reminders. Logout retains the existing cancel-all behavior.
- In-app notification history and email delivery are unchanged. Server push filtering applies even when a second device has stale cache. Local scheduled reminders synchronize when this settings page loads/resumes; there is no new background cross-device preference synchronization. OS permissions and provider availability still govern delivery, including mandatory notifications.

## Deployment comparison

The deployment `app` still uses unscoped `notif_pref_` local keys and must receive this screen/store/scheduler change as a tested unit before an APK is built from that copy. The backend changes are in the selected deployment server source, locally only. The deployment app was not overwritten.

The existing [deployment parity review](DEPLOYMENT_PARITY_REPORT.md) remains applicable: optimistic story deletion/feed coordination, the viewer logout privacy fix and AppCard Material fix are real differences; fullscreen story layout is a separate UI choice. Authentication, passport identity, approved navigation, support-team and streak features are not missing wholesale. Do not copy generated signing files or replace the whole app to reconcile formatting differences. Old deferred server story deletion remains unported.

## Validation

Test databases are isolated local memory-server instances; provider calls in notification tests are mocked.

- Flutter analyze: no issues.
- Flutter full suite: 443 passed. The first run had one failure in the new test because direct assignment bypassed AuthSession's logout notification; the test now calls actual logout and the focused four-test suite and full suite pass. No timeout was increased.
- Backend full suite: 257 passed, zero failures/skips. Focused notification/push/support suite: 10 passed. Changed backend JavaScript syntax: 20 files passed.
- Debug APK build: passed. Existing Flutter warnings about future Gradle/AGP/Kotlin support remain; no toolchain migration or signed release build was performed.
- Deployment application: all 525 checkpoint files unchanged; website: all 264 checkpoint files unchanged. No website package/dependency change in this stabilization step.
- App HEAD remains `3e31e19c5343170056e6d7559c59bfb891f2c624`; deployment HEAD remains `e9060536e8dc7a70150da9c42d6dfac901713553`. Both Git indexes remain empty; all work is still uncommitted.

Logs are under private `.git/stabilization-20261021`: `analyze.log`, `flutter-focused.log`, `flutter-tests-final.log`, `backend-focused.log`, `backend-tests-final.log` and `flutter-build-final.log`. The first full-test failure log is retained separately as `flutter-tests.log`.

The final source checkpoint is saved separately in `app-final` / `deployment-final` beside the pre-change checkpoint, with SHA-256 verified source copies, manifests, binary patches and Git states. The pre-change history bundles remain valid because neither HEAD nor history changed.
