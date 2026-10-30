# Release-readiness checklist — Phase 3

21 October 2026. **Ready for further local/manual QA. Not certified for production release.** No release action is authorized by this checklist.

## IMPLEMENTED

- Following explicit approval, deployment patches 01/02/03/05 are applied to the actual deployment app; fullscreen 04 is intentionally excluded. See [follow-up validation](APPROVED_DEPLOYMENT_PARITY_20261021.md), including remaining deployment analysis diagnostics.

- Authoritative paths and existing worktree relationships retained. Phase 1/2 and subsequent notification work preserved in private verified checkpoints; signing/environment configuration remains private.
- Account-owned notification API/UI integration with strict optional-category validation, default-enabled settings, account cache isolation, failed-write rollback, retry and late-session protection.
- Security/authentication/urgent notification delivery bypasses optional category muting. The user's earlier confirmation establishes this policy; OS permissions/provider availability still apply.
- Static SEO output keeps JSON-LD as script data and validates article/category output path segments. This closes confirmed unsafe output construction, without claiming a public unauthenticated exploit was demonstrated.

## TESTED — local evidence only

- Full authoritative Flutter pub/analyze/test/debug APK validation, backend isolated tests/syntax/audit and website tests/typecheck/build/audit: exact final commands/counts/exits in [PHASE3_VALIDATION.json](PHASE3_VALIDATION.json).
- Final results: Flutter 445 passed, backend 257 passed, website 73 passed; analyze/debug APK/website build passed. Backend syntax 329 files passed, audit zero known vulnerabilities. Website audit remains nonzero with the findings below.
- Notification account ownership/defaults/concurrent partial writes/invalid fields/expired token, single/group push muting and mandatory overrides use an isolated MongoDB and mocked provider delivery.
- Flutter preference tests cover account cache isolation, confirmed writes, failure rollback, offline cached state/retry, late reads across accounts and late saves after logout.
- SEO regression tests use isolated generated fixtures and mocked content, including Arabic slugs, closing script payloads and unsafe article/category paths.
- Proposed deployment patches are checked and exercised in private source copies only; see the [patch review](proposals/phase3/README.md) and final report for exact scope/results.
- Privately patched deployment application: 445 tests passed; deletion without fullscreen: 19 focused tests passed. These results do not approve modifying the actual deployment app or certify its signed build.

## PROPOSED — approval required

- Deployment patches 01/02/03/05 were subsequently approved and applied; do not reapply them. Remaining maintenance needs separate scoped review.
- Decide separately whether to apply 04 (fullscreen story design); it depends on 03 and needs visual/device review.
- Approve separate React Router, Vitest and Tailwind major migrations with the compatibility/rollback checks in [PHASE3_DEPENDENCY_PLAN.md](PHASE3_DEPENDENCY_PLAN.md).
- Plan supported Android toolchain maintenance. Existing Gradle/AGP/Kotlin future-support warnings remain; no validation bypass is used.

## BLOCKED — release assessment

- The approved functional deployment parity subset is applied. Fullscreen 04 remains intentionally excluded, and deployment SDK/lint maintenance remains; use the follow-up results rather than treating the two Flutter copies as interchangeable.
- Website still has advisory-affected dependencies: 15 total affected package entries, including 2 moderate production Router entries. Passing tests does not remove these findings.
- Coordinated server/app release must provide the new preference API before relying on the screen. Local changes are uncommitted/unpublished and have not reached production.
- Existing shared node_modules junctions may differ from the selected lockfile; clean isolated website validation does not repair the developer installation. Plan an approved isolated dependency installation/junction change before normal local website work assumes lockfile parity.

## NOT TESTED — required manual/provider/device QA

- Real registration/SMTP verification and password recovery delivery; real Google OAuth on Android/iOS/web and mobile handoff; production credential/redirect configuration.
- Physical Android push permission, background/killed-app delivery, urgent/security sound and OS Do Not Disturb behavior; real OneSignal delivery. Already queued local reminders do not receive automatic cross-device cancellation until settings synchronization.
- iOS compile/signing/device behavior (Windows lacks Xcode); signed Android release/store installation and upgrade/migration from a published build.
- Manual role-based discovery/application/upload/reuse/support/notifications/story/scholarship/alumni flows against a deliberately isolated staging environment. Automated mock/local API tests are not a full physical-device end-to-end pass.
- Real cloud storage/scanning/video and passport/OCR device behavior, provider latency, accessibility/Arabic RTL visual review, offline transitions on device and measured messaging/frame/memory performance.
- Production database contents/index health, backups/restore rehearsal, production observability and staged rollout. No production connection or destructive migration was performed.

Keep all old copies and recovery points. Do not treat historical cleanup proposals as new deletion approval. No commit, push, deployment, source deletion, credential change or repository relocation occurred in Phase 3.
