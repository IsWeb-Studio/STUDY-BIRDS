# Study Birds — Phase 3 stabilization and release assessment

**Subsequent owner-approved action:** patches 01/02/03/05 were applied to the actual deployment app after this assessment; fullscreen patch 04 remains excluded. The baseline and proposal statements below describe the original Phase 3 snapshot. Current follow-up evidence is in [APPROVED_DEPLOYMENT_PARITY_20261021.md](APPROVED_DEPLOYMENT_PARITY_20261021.md).

21 October 2026. Continued the existing Phase 1/2 audit and subsequent notification stabilization. This is a local assessment, not production certification. **No commit, stash, reset, rebase, push, deployment, deletion, credential change or authoritative-directory relocation was performed.**

## Starting state and preservation — IMPLEMENTED / TESTED

Authoritative Flutter remains `D:\work\studybirds_app\study_birds_app-main`; backend and website remain `D:\work\studybirds_session_release\server` and `client`. Deployment `app` remains a distinct, unchanged release input. Existing Git worktree relationships and overlapping parent repositories were retained.

The reports' source selection and feature comparisons still match the working tree. Historical statements that notification endpoints are missing are superseded by [the subsequent implementation](STABILIZATION_20261021.md). Likewise, the eight historical cleanup targets were already handled under a separate explicit approval; Phase 3 grants no new cleanup and performs none. Earlier report counts are snapshots, not the current dirty-file count.

At Phase 3 start, collapsed `git status --short` showed 34 entries in the app and 23 in deployment (not the older approximate 30/16). At completion, the corresponding counts are 38 and 26. The complete expanded statuses and Phase 3-only changed paths are recorded in the validation JSON; untracked directories may contain multiple files behind one collapsed entry.

Before new source edits, `.git/phase3-20261021/app-pre` and `deployment-pre` received 542 and 1,162 tracked/untracked files respectively, copied and SHA-256 verified. Captured HEAD/status, binary working-tree/staged patches and a fresh private configuration checkpoint (5 files, hashes verified; no values displayed). Existing verified history bundles remain valid because HEAD/history did not change. Prior checkpoints were not overwritten. Free space before preservation: C 32,084,459,520 bytes; D 5,749,592,064 bytes. These are local recovery points, not an off-device backup.

`lib/screens/export.dart` was absent. A new 45-second read-only recursive lib watcher recorded zero changes before source editing. Language tooling, editors, a Gradle JVM and other Codex processes existed; their existence alone does not prove source writes. No concurrent writer was identified, no unexplained source-write event was observed and no unrelated process was terminated. The earlier transient file's source remains unknown; observation does not prove it cannot recur.

## Notification feature — IMPLEMENTED / TESTED, with explicit limits

The prior stabilization already implemented authenticated GET/PUT, strict seven-category patches, partial-update persistence, default-enabled settings, account-scoped local cache, failed-write rollback and late-session guards. It was reviewed against current ApiClient/auth middleware, User/Notification models and single/group push paths; the old proposal was not blindly applied. The mounted API path matches Flutter's request contract.

The user explicitly approved mandatory security and emergency delivery. Explicit mandatory/security/urgent notices bypass optional filtering; unknown notices are not guessed from title/body or silently categorized as announcements. Emergency support producers pass mandatory metadata. In-app history and email behavior remain unchanged. No policy was invented about intentionally external website URLs or new notification categories.

Phase 3 adds two Flutter regressions: offline load uses only the current account's cache and retry loads fresh server state; a PUT completing after logout cannot overwrite local cache or display a stale error. Backend integration additionally asserts expired JWT rejection at the preference endpoint, alongside its existing real isolated persistence/ownership/concurrent update/input/provider-filter tests.

The six Flutter preference tests pass. Local reminders consult the account cache and disabled queued categories are canceled when settings synchronize. **Already queued local reminders are not canceled remotely in the background on another device**; this remains a documented integration limit. Actual OS/OneSignal delivery, background scheduling and device permission behavior remain NOT TESTED. Mandatory policy bypasses account-category muting, not OS restrictions.

## Website JSON-LD fix and output-path guard — IMPLEMENTED / TESTED

`client/scripts/generate-seo-files.mjs` previously placed JSON.stringify output directly in a raw script element. Article schema strings containing a closing script tag could terminate JSON-LD markup; schema headline/author fields originate in content metadata. It also joined article/category slugs into output paths without its own path-segment check. Current backend slug/category normalization restricts normal producer output, so the path guard is defense in depth at the build boundary, not a demonstrated traversal through that backend. Public unauthenticated exploitability/production content permissions were not demonstrated.

The generator now escapes JSON-LD's HTML-sensitive characters while preserving JSON values, and refuses traversal, separators, encoded path syntax, control/invalid Windows characters, reserved device names and trailing-dot output segments. Arabic slugs remain supported. No runtime dependency upgrade or layout change is involved.

Eight Node-environment Vitest regressions execute the actual generator with mocked content in retained temporary fixtures: malicious script text round-trips as JSON data, valid Arabic output, six unsafe article slugs and an unsafe category slug. No hosted content API is contacted by these tests. The first full website build exposed missing Node type declarations for this test; added matching Node 22 development types and undici-types after verifying no other package entries changed. Full website build validation uses an explicit empty local SEO fixture, not production content. Real published catalog SEO output remains manual QA.

## Deployment application parity — PROPOSED

Five reviewed patches and their behavior/risk/dependency notes are in [proposals/phase3](proposals/phase3/README.md): privacy after logout; Material card surface; optimistic story deletion/feed rollback; separate fullscreen design; account notification preferences. They contain source and regressions, not generated signing/configuration files.

The privacy behavior and Material fix are narrow correctness fixes. Optimistic deletion is a coordinated repository/feed/viewer unit retaining the current DELETE contract. Fullscreen versus card layout is a product/interaction choice and remains separate. Authentication/password/email gates, approved navigation, passport identity, support teams and streak features remain shared; no whole-app replacement is justified. The deferred server-deletion experiment is still excluded.

Sequential apply checks succeeded against a private copy of the exact deployment app. Actual deployment app files have not been edited. The full privately patched application passed 445 tests. The deletion-without-fullscreen variant passed 19 focused tests. Its first run exposed a generated regression file with an extra closing brace; corrected the patch composition, retained the failed log (1 passed / 3 failed loads), and reran without disabling assertions. Final regenerated fully patched source matches the full-tested copy byte-for-byte across 528 source entries; the correction changes the intermediate patch composition, not the full assembled implementation. Applying any patch to the actual deployment app requires owner approval under section 6 of the Phase 3 request, plus rechecking current source state.

## Functional review — TESTED locally / NOT TESTED live

- Registration/login and Google: inspected current auth/password/email gates and website role/mobile redirects; Flutter `google_password_gate_test.dart`, `live_session_flows_test.dart`, backend `authSecurity.test.js` / `webSessionSecurity.test.js` and website auth/session suites provide mocked/local evidence. Real provider sign-in and real email delivery are NOT TESTED.
- Session expiration/logout/account switching: Flutter `mobile_session_security_test.dart` and live-session/preferences tests, backend revoked/expired token checks, website `authSecurity.test.ts` / `sessionSecurity.test.tsx` exercise stale responses and identity clearing. No production sessions were accessed.
- Roles/authorization: reviewed backend protect/authorize and website ProtectedRoute role/employee permission logic; backend private-document/support-team/capability tests enforce ownership and assigned-team access. Client route hiding is not the authorization boundary. Manual full role navigation is NOT TESTED.
- University discovery/application submission: reviewed shared catalog/application integration and existing program filters/revision/requirement/assignment suites plus Flutter `program_application_test.dart`. No new confirmed low-risk defect was found in the inspected scope. Complete browser/device discovery-to-submission clickthrough remains NOT TESTED.
- Document upload/reuse: Flutter library flows explicitly select saved IDs and test confirmed upload updates; backend upload/private-document/application-document tests cover validation/ownership. Real cloud storage, antivirus/OCR and device pickers are NOT TESTED.
- Notifications and stories: preference tests and existing server story ownership/viewers/rewards plus Flutter deletion/viewer/video/gesture suites provide local evidence. Real push delivery, media providers and device performance remain NOT TESTED.
- Scholarships/alumni jobs: Phase 2 real MongoDB/local HTTP regressions are retained and rerun in the full suite, including expiry plus field filtering and named-route ordering/private-profile checks. Exhaustive Flutter/browser alumni-job and scholarship clickthrough is NOT TESTED.
- Offline/API failures: Flutter `network_resilience_test.dart`, `offline_ui_test.dart`, connectivity and preferences tests plus website `apiResilience.test.ts` / `connectivity.test.ts` exercise bounded GET retries, non-retried writes, safe errors and session preservation. Real airplane-mode/background/reconnect behavior is NOT TESTED.

This is a bounded integration/code/test review, not a claim that all listed flows completed end-to-end on real devices and production services. No destructive test used a production database; the existing backend harness creates isolated local memory databases and uses network isolation.

## Dependency security — PROPOSED / BLOCKED for release certification

Fresh website audits reproduce 15 affected entries: 7 moderate, 6 high, 2 critical. Production-only: 2 moderate Router entries. Compatible dry-run changes zero packages. No force update, broad override or major migration was applied. Detailed current applicability and separate Router/Vitest/Tailwind migration acceptance requirements are in [PHASE3_DEPENDENCY_PLAN.md](PHASE3_DEPENDENCY_PLAN.md); the earlier per-package review remains applicable. Reduced reachability is not a vulnerability fix. Backend audit and exact final outputs are recorded in the validation JSON.

Existing shared node_modules junctions remain unchanged; website validation uses the isolated installation matching the selected lockfile. This does not fix a developer dependency tree behind a junction or authorize replacing it. Android future Gradle/AGP/Kotlin support warnings remain. No release-signing/configuration migration was attempted.

## Validation and final state

Exact commands, roots, exit codes, counts, modified paths and final Git status are in [PHASE3_VALIDATION.json](PHASE3_VALIDATION.json). Private logs/checkpoints remain under `.git/phase3-20261021`; original source and previous checkpoints are preserved.

- Authoritative Flutter: pub get/analyze/test/debug APK all exit 0; analyze no issues; 445 tests passed.
- Backend: npm test exit 0, 257 passed / 0 failed / 0 skipped (211 top-level tests). Syntax checks: 329 files, zero failures. npm audit exit 0, zero known findings.
- Website: final npm test exit 0, 73 passed / 11 files; final npm run build exit 0, including TypeScript, Vite and isolated SEO fixture. Initial build exit 1 for missing Node type declarations is retained; final run fixes the dependency rather than excluding the test or suppressing diagnostics.
- Website audits exit 1 due to remaining findings, not a command/setup failure: 15 full / 2 moderate production entries. Compatible remediation dry-run exit 1 with zero package changes. Runtime dependencies unchanged; only the explicitly reviewed Node development types were added.
- Privately patched deployment Flutter: pub get and complete 445-test suite exit 0. Corrected intermediate deletion variant: pub get and 19 focused tests exit 0. The initial malformed generated-test attempt remains recorded, not hidden.
- Validation source/config/lock equality and original deployment-app hashes are rechecked at completion. No real deployment source/app change was made. Git indexes/history/HEADs remain unchanged; all work stays uncommitted.

Phase 3's active source/test/manifests changed are `test/notification_preferences_test.dart`, `server/tests/notificationPreferences.test.js`, `client/scripts/generate-seo-files.mjs`, `client/src/lib/seoBuild.test.ts`, `client/package.json` and `client/package-lock.json`. README links, the four Phase 3 report/checklist/plan files and six deployment proposal files are also added/updated. Flutter production notification code was implemented in the preceding stabilization step and retained; Phase 3 extends its validation. Full Git status includes preserved earlier changes and is not presented as newly implemented Phase 3 work.

A separate final private checkpoint (`app-final` / `deployment-final`) contains the completed source/reports/patches and manifests, with every copied file SHA-256 verified. Pre-change recovery points and prior verified Git history bundles remain separate. Private generated validation copies, build artifacts and test fixtures were retained; nothing was cleaned up.

## Readiness and decisions

The selected sources are suitable for further isolated manual QA if the recorded validation remains green. They are **not certified production-ready**: website advisories, unapplied deployment parity, real-device/provider/iOS/signed-release validation and coordinated release review remain. See [RELEASE_READINESS_CHECKLIST.md](RELEASE_READINESS_CHECKLIST.md).

Next approvals are concrete: choose deployment patch units (01/02/03/05 recommended for correctness, 04 separately for fullscreen design); approve the three independent major dependency migration plans; schedule device/macOS QA and later release/toolchain work. No deletion, commit, push or deployment is implied by any of these proposals.
