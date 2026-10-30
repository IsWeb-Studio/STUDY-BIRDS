# Project audit and stabilization report

Date: 21 October 2026. Scope: local Flutter application, selected API and website, and bounded discovery of related C:/D: copies. This is evidence from this session, not a production-readiness certification.

## Outcome and authoritative workspace — VERIFIED

- Application: `D:\work\studybirds_app\study_birds_app-main`, `https://github.com/aboodsiaj2/fsfs.git`, `main`, starting HEAD `3e31e19c5343170056e6d7559c59bfb891f2c624`.
- API: `D:\work\studybirds_session_release\server`; website: sibling `client`, in `https://github.com/IsWeb-Studio/STUDY-BIRDS.git`, starting HEAD `e9060536` (see inventory for full hash). This is an existing detached worktree, not an independent disposable clone.
- Selection uses commit/features, source hashes, existing tests and build results, not directory age. The active app has optimistic story deletion and additional tests missing from the deployment repository's app. The selected server contains the recent email verification, passport identity, support team and story-viewer APIs absent or different in older copies.
- Keep both existing repositories and paths. Their logical pairing is documented; source relocation is **REQUIRES APPROVAL**, and no relocation was performed. A future `D:\work\StudyBirds\app` and `web` layout would require a separate worktree/junction/dependency plan. The current paths are the safest operational workspace now.

## Discovery — COMPLETED within the stated scope

61 manifest/repository entries and 37 related ZIP archives were inventoried. Counts include nested packages, not 61 independent repositories. Thirteen project repository/worktree roots were identified. Exact paths, initial Git states, logical sizes, hash differences, copy-only files and cleanup recommendations are in `DUPLICATE_INVENTORY.md` and its JSON companion.

The app and selected deployment worktree began clean. Other locations contained staged/unstaged work: the parent app repository, original web checkout, stories worktree, Google-password worktree and nested monorepo. They were preserved. An unrelated Git repository at the Windows home directory was excluded from project attribution; downloaded folders are not treated as that project's repositories.

Initial free disk space: C approximately 35.05 GiB; D approximately 2.42 GiB. Flutter build caches are already linked to C. Source remains on D. Directory sizes exclude junction targets and are not physical NTFS allocation estimates.

Verified tools: Flutter 3.47.5, Dart 3.13.4, Node 22.19.0, npm 10.9.3, Java 17, Git and Android SDK. A second Flutter SDK exists and is a source of possible local version drift. CI and editor configuration already select 3.47.5.

## Recovery — VERIFIED

Before source edits, 526 app/configuration files were copied and SHA-256 verified, and `app.bundle` passed `git bundle verify`. A further 335 backend tracked files were copied and verified; available backend environment/manifests were preserved separately. Following explicit authorization for local client changes, 265 website/configuration files were also checkpointed and verified.

Private checkpoint: `.git/audit-20261021/checkpoint`. This is not uploaded or committed and must not be shared: it includes private configuration and signing material. See `MAINTENANCE_GUIDE.md` for file-specific recovery. No pre-existing dirty work was reset or overwritten.

## Implementation — COMPLETED

1. **Private story-viewer state:** logging out while the viewers page remains mounted could leave names visible. The page now observes session changes, clears private rows/counts/cursors, unregisters its listener on disposal, blocks further loads and ignores late responses. A regression test loads names, starts another page, logs out and resolves the late response, asserting neither old nor late identities remain visible.
2. **Card interaction rendering:** the complete Flutter suite exposed the Flutter assertion that `ListTile` ink effects were hidden beneath an `AppCard` background. Both tappable and ordinary cards now provide a local transparent `Material` surface. The existing RTL/LTR profile placement test verifies the screen without framework exceptions; card appearance and spacing remain unchanged.
3. **SDK deprecations and lint cleanup:** replaced three deprecated `TickerMode.of` calls with the supported `.valuesOf(...).enabled` equivalent, added missing flow-control blocks, removed redundant nested constants and used stdout in the command-line error-policy tool. No lint rules were disabled. Formatting was confined to changed files; a repository-wide formatting rewrite was not performed.
4. **Stale backend regression expectations:** Google tests now assert that a provider-verified email does not bypass the application's explicit local verification gate, including repeat login and stored state. CRM ticket assignment and private attachment tests now establish the student's actual support team and assert denial before assignment. Existing 2FA, ownership, document privacy and concurrent-reply assertions remain.
5. **Repeatable backend tests:** added a real `npm test` entry point and declared the already-required MongoDB memory-server test dependency. The runner supplies a fresh local replica set for five previously opt-in tests, overrides database URI variables, disables runtime binary downloads, uses the existing network-isolation preload and shuts down its test database. An initial synchronous child-process implementation stalled MongoDB output; it was corrected to asynchronous process execution and the five opt-in tests then passed together.
6. **Compatible website security updates:** after explicit local-client approval, updated the lockfile within existing manifest constraints. Notable versions: Axios 1.15.2 → 1.20.0, PostCSS 8.5.12 → 8.5.31, React Router 6.30.3 → 6.30.6, Vite 6.4.2 → 6.4.5, plus affected transitive packages. No force update or major migration was applied. The shared existing `node_modules` junction was left intact; validation uses a clean isolated dependency install.
7. **Accurate documentation:** replaced the stale README (wrong API defaults/paths and a mixed-encoding NUL-containing tail), and added architecture, setup, inventory, recovery and maintenance documentation. The original bytes remain in the checkpoint.

No source files, user data, external directories, APKs, environment files, signing keys or branches were deleted. No dead code or assets were removed based on names or static reference absence. Folder assets and native integrations make such removal unsafe without dedicated proof. No duplicate feature modules were blindly consolidated.

## Integration and security — PARTIALLY COMPLETED

The inspected app defaults to `https://study-birds1.onrender.com/api`, supports explicit environment overrides and requires HTTPS/trust-bundle validation in release. Authentication persistence uses secure storage; account snapshots are scoped and encrypted. Backend authorization checks token validity, active users, revocation and token version; private resources add ownership/team rules. Regression suites exercise authentication, sessions, documents, programme revisions, story ownership, support teams, uploads and financial operations against isolated databases.

The deployment app is **not** identical to the fsfs application: initial source-scope comparison found 150 differing files and 18 missing files relative to the selected app, including tests and native sources. No wholesale synchronization was attempted. Any release needs deliberate feature-by-feature parity review.

The tracked-app secret-pattern scan found no matching private keys, provider service-account keys, GitHub tokens or Render tokens in the scanned text scope. Signing files are ignored; the tracked private-key fixture is test material. This is a bounded pattern check, not a full historical secret audit. A sensitive provider configuration filename exists in Downloads; it was not exposed in documentation. Historical Git objects, live account permissions and production secret validity were **NOT TESTED**; rotate only if actual exposure is confirmed, with owner approval.

API dependency audit reported zero known vulnerabilities before and after adding the test dependency. Website dependency audit decreased from **24** (1 low, 8 moderate, 13 high, 2 critical) to **15** (7 moderate, 6 high, 2 critical) affected package entries after compatible updates. Entries include transitive propagation and are not a count of distinct exploitable production flaws.

Remaining website findings include Vitest/Tinypool, older Vite used by test tooling, Tailwind transitive parsing/globbing packages and React Router. Several require major migrations according to npm. Their applicability differs: Vitest UI/server findings concern developer tooling; the React Router redirect finding concerns navigation handling, while its SSR hydration finding needs SSR use. This app's static client build does not prove all reported paths are reachable or harmless.

Primary advisory references reviewed: [Tinypool](https://github.com/advisories/GHSA-5gmw-xhrv-c9v3), [Vitest UI server](https://github.com/advisories/GHSA-5xrq-8626-4rwp), [React Router redirect](https://github.com/advisories/GHSA-wrjc-x8rr-h8h6). Review and test major migrations separately. No production configuration or credential rotation was performed.

## Validation evidence

Raw local logs and machine-readable audit data are retained under `.git/audit-20261021`; they are private local evidence, not public artifacts. Native command exit codes were captured separately from PowerShell wrapper completion. Do not interpret PowerShell's stderr formatting as the command result.

- **VERIFIED:** `flutter pub get`, exit 0.
- **PARTIALLY COMPLETED:** full `dart format --output=none --set-exit-if-changed .`, exit 1; baseline 275 files inspected, 152 would change. This command did not rewrite those files. Changed-file formatting subsequently passed, exit 0, 11 files with 0 further changes.
- **VERIFIED:** final `flutter analyze`, exit 0, no issues. Initial pass reported 13 informational diagnostics; all addressed without rule suppression.
- **VERIFIED:** final `flutter test --reporter expanded`, exit 0, **439 tests passed**. The first run exposed the card issue; the new private-state test also demonstrated the old compiled behavior. Focused rerun passed 8 tests, followed by the successful full suite.
- **VERIFIED:** `flutter build apk --debug --no-pub`, exit 0; `build/app/outputs/flutter-apk/app-debug.apk`, 375,359,682 bytes. This is a debug build, not a signed store release. Existing release APKs were preserved.
- **VERIFIED:** final `npm test`, exit 0, **252 tests passed, 0 failed, 0 skipped**, with a new isolated replica set. Five formerly opt-in integration tests also passed in a focused run, exit 0. Initial failures and an intermediate harness timeout are retained in separate logs; the final asynchronous runner suite passed in 219.5 seconds. JavaScript syntax checks passed for 238 source/script files; `node --check scripts/run-tests.cjs` also passed after its final whitespace cleanup.
- **VERIFIED:** updated-lockfile website validation in `.git/audit-20261021/client-validation`: clean `npm ci --ignore-scripts`, exit 0; `npm test`, exit 0, **65 tests / 10 files passed**; `npm run build`, exit 0, TypeScript/Vite/SEO completed. This isolated directory does not contain private .env files. Original shared dependency junctions were not modified.
- **VERIFIED:** initial website `npm test`, exit 0, 65 tests across 10 files; initial `npm run build`, exit 0, TypeScript/Vite/SEO generation completed.
- **NOT TESTED:** iOS build/signing/device behavior; Windows does not provide Xcode.
- **NOT TESTED:** live database data/schema, production SMTP/Cloudinary/provider credentials, physical-device performance, offline field behavior and full manual end-to-end production flows.

## Build/dependency warnings and limitations

The debug APK built with existing Gradle/AGP/Kotlin versions, but Flutter warns about future support removal. A toolchain migration is deferred until compatibility can be tested. No dependency-validation bypass flag was used.

`flutter pub outdated --no-dev-dependencies` completed, exit 0; it reports 41 upgradable locked dependencies and 24 constrained below a resolvable version. Transitive `flutter_secure_storage_macos` and `js` are discontinued. No blanket Flutter package upgrade was performed; the current dependency set passed the application suite and Android debug build. See [Dart's outdated documentation](https://dart.dev/tools/pub/cmd/pub-outdated) for interpretation; outdated does not itself establish insecurity.

No separate backend lint/build scripts existed. JavaScript syntax checking and isolated Node tests are the applicable API validation, not a fabricated compilation result. A clean server dependency reinstall was not performed because its existing dependency directory is a shared junction; the test helper uses the declared version already installed locally.

## Architecture, performance and maintenance debt

The existing feature/repository/service architecture was preserved. No UI redesign, state-management migration or forced monorepo was introduced. Static analysis covered the Dart tree; manual review focused on authentication, transport, cached data, authorization, story state, uploads, bootstrap and native/build configuration. A line-by-line security review of every route and dependency, or exhaustive manual testing of every feature, is not claimed.

Measured source scope: 174 application Dart files / roughly 55,004 lines, and 233 backend source JavaScript/CommonJS files. Large screens, service/UI coupling and circular imports remain technical debt. Avoid speculative performance claims: no device frame timings, memory profiles or production database query plans were collected. The completed reliability fixes concern verified session state and interaction behavior, not measured startup or messaging speed gains.

## Git and deployment

Existing histories, remotes, branches, staged work in other copies and worktree relationships were preserved. Audit changes are local and reviewable; no history was rewritten, no branch deleted and no production deployment triggered. A final status/file list is appended below after validation. Backups and evidence are under Git metadata and must never be staged wholesale.

## Cleanup and next actions — REQUIRES APPROVAL / PARTIALLY COMPLETED

Six exact redundant ZIP alternatives account for **6,207,107 bytes (5.92 MiB)** on C. Two additional, verified untracked Android intermediates directories in old clean copies account for **3,572,198,395 bytes (3.327 GiB)** on D. Their exact eight paths and retained parent/source/archive counterparts are in `DUPLICATE_INVENTORY.md`. Combined logical recovery estimate: **3.333 GiB**. The generated targets contain no APK/AAB, .env, signing keys, tracked files or nested links; rebuilding them costs time. **Wait for explicit approval before deleting those external files.** No source directory or active cache is on the deletion list.

Keep unique/dirty copies and recovery bundles until their changes are resolved. Preserve the original web repository because common worktrees and dependency junctions rely on it. Bigger disk recovery needs a separate review of generated output and signing/configuration dependencies.

Next: review major website security migrations; reconcile deployment-app parity one feature at a time; plan a supported Android toolchain upgrade; validate iOS on macOS; add off-device private backup; then approve only an exact deletion/relocation list. These remaining items prevent claiming comprehensive production readiness.

## Final local file/Git status

Read-only remote main checks matched both starting HEADs (`3e31e19` for fsfs, `e906053` for deployment main). No unmerged Git index entries were found. Changes remain uncommitted and unpushed for review; production was not redeployed. `git diff --check` passed in both repositories.

Application modified files:

- `?? docs/AUDIT_VALIDATION.json` (machine-readable final command results).
- `M README.md`
- `M lib/core/widgets/app_components.dart`
- `M lib/screens/applications_documents_payments/documents_screens.dart`
- `M lib/screens/home_journey/notifications_screen.dart`
- `M lib/screens/home_journey/student_banner_carousel.dart`
- `M lib/screens/roles/employee_dashboard_screen.dart`
- `M lib/screens/stories/story_viewers_screen.dart`
- `M test/chat_controls_test.dart`
- `M test/journey_requirements_test.dart`
- `M test/post_admission_journey_test.dart`
- `M test/story_viewers_test.dart`
- `M tool/check_error_policy.dart`
- `?? docs/ARCHITECTURE.md`
- `?? docs/BACKEND_ENVIRONMENT_NAMES.json`
- `?? docs/DEVELOPMENT_SETUP.md`
- `?? docs/DUPLICATE_INVENTORY.json`
- `?? docs/DUPLICATE_INVENTORY.md`
- `?? docs/MAINTENANCE_GUIDE.md`
- `?? docs/PROJECT_AUDIT_REPORT.md`

API/website modified files:

- `M client/package-lock.json`
- `M server/package-lock.json`
- `M server/package.json`
- `M server/tests/auditFixes.test.js`
- `M server/tests/crmIntegration.test.js`
- `M server/tests/privateDocumentAccess.test.js`
- `?? server/scripts/run-tests.cjs`

Checkpoint re-verification at completion: **1,126 file hashes matched** across application/configuration, backend and website backups. README no longer contains NUL bytes. No source files were removed. Remaining work: major security/toolchain migrations, deployment-app parity, physical-device/iOS validation, off-device private backup, and explicitly approved external cleanup/relocation.
