# Study Birds — Phase 4 deployment parity and security hardening

**Subsequent approved Router migration:** website Router 7.18.4 is now installed/tested locally, with 100 tests passing and audit counts 13 total / 0 production. The Phase 4 baseline counts below remain historical. Current evidence: [REACT_ROUTER_UPGRADE_20261021.md](REACT_ROUTER_UPGRADE_20261021.md).

21 October 2026. Continued from Phase 3 and the subsequent approved patch application. No earlier audit/cleanup was restarted. No commit, push, deployment, source deletion, reset, stash, production access, credential/signing change or worktree relocation was performed.

## Patch state — IMPLEMENTED previously, VERIFIED in Phase 4

Units 01 (viewer privacy), 02 (Material card), 03 (optimistic deletion/feed/rollback) and 05 (account notification preferences) were already applied by the preceding explicitly approved action. Phase 4 verifies that state; it does not claim a second implementation.

Current source hashes matched the preceding verified post-application checkpoint. Combined `git apply --reverse --check` succeeded (exit 0), proving the four patches are present. Forward `git apply --check` returned 1 because the changes already exist; no force/replay was attempted. This is an already-applied disposition, not a newly discovered conflicting patch. The actual viewer retains `story-card` and its existing contain/card layout. **04 remains excluded by instruction.** No whole-directory synchronization occurred.

Before edits, `.git/phase4-20261021/app-final` and `deployment-final` captured 553 and 1,166 tracked/untracked files respectively, with SHA-256 verification, HEAD/status and binary diffs. For this phase these labels are pre-change checkpoints. Six existing environment/example/local/signing configuration files were preserved privately with hashes; no values were exposed. Earlier checkpoints were retained. Initial free disk bytes: C 31,559,876,608; D 4,975,734,784. Generated caches remain where the existing tools place them; source folders are not moved.

## Actual deployment-app validation

All Flutter commands run from `D:\work\studybirds_session_release\app` using `C:\src\flutter\bin\flutter.bat`. Results are not borrowed from the authoritative app or a private patch copy.

- `flutter pub get`: exit 0.
- `flutter analyze`: exit 1, **279 informational diagnostics, 0 warnings, 0 errors**. This is not a clean static-analysis pass. Previous evidence locates 276 diagnostics in unchanged files and three on already-existing lines in the story viewer/feed. No lint rule was disabled or extra SDK-maintenance patch introduced.
- `flutter test --reporter expanded`: exit 0, **444 passed, 0 failed**. Includes deletion request deduplication/failed-request restoration, immediate exact-route removal, logout privacy/late pages, account-switch/session races and six account-preference save/offline/retry/late-response tests. The fullscreen-only regression remains absent with patch 04.
- `flutter build apk --debug`: **exit 0**, Gradle assembleDebug 174.5 seconds. Artifact: `D:\work\studybirds_session_release\app\build\app\outputs\flutter-apk\app-debug.apk`, 320,844,144 bytes, SHA-256 `9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23`. No signed release/store build or device installation is claimed.

Private logs are under `.git/phase4-20261021`. Existing Gradle/AGP/Kotlin future-support warnings remain; no dependency-validation bypass or signing fallback was introduced.

Post-build hashes confirm all checkpointed application/backend/website source and manifests are unchanged. The existing Android debug signing key is byte-identical. Flutter added only generated `flutter.buildMode`, `flutter.versionName` and `flutter.versionCode` entries to ignored deployment `android/local.properties`; SDK-path fields and signing files are unchanged, and the original local properties remain in the private pre-build checkpoint. No source/build configuration patch was needed to compile. A post-validation checkpoint preserves the finished reports/current source separately.

Flutter also generated the missing ignored Gradle wrapper/plugin/build outputs required for this checkout's debug build. These generated files do not represent a source migration or a change to tracked Gradle version configuration. The APK remains in its build-output folder; only its metadata/hash, not a second large APK copy, is included in the source recovery evidence.

Authentication, authorization, API/notification contracts, backend and website source remain unchanged in Phase 4. Therefore no backend/website regression suite was rerun for a new shared-contract change. Their last Phase 3 results (257 backend / 73 website tests) are historical evidence, not new Phase 4 test passes. No provider/database test was directed to production.

## Security dependency work — REVIEWED, major migrations PROPOSED

Fresh website `npm audit --json`: exit 1, **15 affected package entries: 7 moderate, 6 high, 2 critical**. Production-only audit: exit 1, **2 moderate Router entries**. Compatible `npm audit fix --package-lock-only --ignore-scripts --dry-run --json`: exit 1 due to findings, **0 added / 0 removed / 0 changed**. No independently verified compatible security update was available from that resolution. No manifest/lockfile/runtime dependency change, force update or broad override was applied.

Package counts include propagated findings, not 15 proven production exploit chains. Router navigation input remains production-relevant; reviewed client rendering does not use SSR hydration. Critical Vitest/Tinypool and nested Vite/esbuild findings concern development/test tooling in the current configuration; absence of a demonstrated public API route does not patch them. Tailwind findings concern the CSS/source processing chain. Existing detailed applicability remains in Phase 2/3 reports.

Prepared [three isolated implementation plans](proposals/phase4/SECURITY_MIGRATIONS.md), with engine/peer checks, independent source copies, acceptance tests and rollback boundaries. npm metadata for the reviewed Router 7.18.4 and Vitest 5.0.5 targets is compatible with the current engine/peer versions at the declared-range level. This is not a migrated test pass. Tailwind 4.3.3 also requires an explicit browser-support/visual decision. None of the three major migrations has been installed or applied; owner approval is required first. Shared node_modules junctions are untouched.

Initial npm stdout/stderr mixing produced an unreadable JSON capture; clean audit/metadata records were subsequently captured with separate streams and parsed successfully. Both records are retained. No advisory was filtered out to obtain a successful parse.

## Current readiness and decisions

The generated debug APK is ready for further controlled real-device QA with an explicitly selected QA API. Production readiness is **not established**: deployment static-analysis debt, website advisories, real-device/background push/media/OCR/provider QA, iOS and signed-release/upgrade checks remain. Debug compilation does not exercise SMTP, Google, OneSignal or production data.

The default API URL is still the existing hosted API; compilation makes no app API requests. Use an explicitly selected isolated QA API/environment for live device flows, especially the newly implemented preference endpoints that have not been deployed by these phases. Do not infer production endpoint availability from mocked/local integration tests.

Before publishing, obtain approval for each major security migration, browser-support decisions, any additional SDK/lint/toolchain maintenance, coordinated server/app release and the actual publishing action. Patch 04 remains a separate, unapproved design choice. No approval was expanded into deployment or cleanup.

Exact current Git states, modified paths, source/config verification and command exits are recorded in `PHASE4_VALIDATION.json`; the actionable checklist is [UPDATED_RELEASE_READINESS.md](UPDATED_RELEASE_READINESS.md).

The fresh build consumed generated-output space on D: free space immediately after build was 1,428,025,344 bytes (about 1.33 GiB), before the final small source checkpoint. Nothing was removed to reclaim it. Check capacity before another full build; this report is not cleanup authorization.
