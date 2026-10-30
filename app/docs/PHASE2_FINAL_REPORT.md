# Study Birds — Phase 2 final report

21 October 2026. Continued from the existing audit; no unnecessary filesystem rediscovery. All implementation is local. **No push, deployment, commit, stash, reset, history rewrite, repository move or external deletion was performed.**

## Authoritative development sources — VERIFIED

- Flutter: `D:\work\studybirds_app\study_birds_app-main`, fsfs repository, `main`, HEAD remains `3e31e19c5343170056e6d7559c59bfb891f2c624` plus preserved local Phase 1/2 work.
- Backend: `D:\work\studybirds_session_release\server`.
- Website: `D:\work\studybirds_session_release\client`.
- Backend/website belong to the same deployment worktree, HEAD remains `e9060536e8dc7a70150da9c42d6dfac901713553` plus local work. Branches, remotes and worktree relationships were retained.

The candidates remain appropriate after semantic review; raw file counts did not justify changing them. Open `.vscode/StudyBirds.code-workspace` to see the three correct folders without relocation. All three relative paths were checked to resolve to the intended existing sources.

## Recovery and preservation — VERIFIED

Before Phase 2 source changes, **1,687 active tracked/untracked files** across app and deployment source were copied and SHA-256 verified under `.git/phase2-20261021/checkpoint`. `checkpoint-manifest.json` records hashes; initial statuses and HEADs were captured. The private Phase 1 checkpoint still preserves ignored signing/environment/native local configuration. No private recovery archive was uploaded.

Dirty old repositories were read and their statuses/diff summaries captured. Their files/indexes were not reset, stashed, committed, overwritten or deleted. The older parent app repository overlaps the active application's physical path, so its modified nested-app paths must not be treated as another independent copy or staged wholesale. The underscore stories path in the request was absent; the actual hyphenated worktree was reviewed.

## Actual fixes — COMPLETED AND TESTED

Recovered narrow valuable pending work into the selected backend:

1. **Alumni jobs:** moved the wildcard user-profile GET after named routes, fixing `/alumni/jobs` being incorrectly handled as an invalid user ID. Public/private profile authorization remains covered.
2. **Scholarships:** field matching now ANDs with availability; searching by field no longer discards expiry restrictions and returns expired scholarships.
3. **OTP configuration safety:** replaced three public `'dev'` HMAC fallbacks with one required-secret helper. Configured SMS/WhatsApp digests remain identical; missing or empty secret configuration fails closed. No credential was printed, rotated or configured.
4. **Seed safety:** destructive seed refuses `NODE_ENV=production` before database/model imports. Its refusal was tested in a subprocess with a temporary working directory; no seed/database operations were executed. Existing unrelated development seed/import compatibility was not changed.
5. **Configuration privacy:** removed two unnecessary recipient/from-address configuration logs in the contact handler; response/error handling remains.
6. **Workspace clarity:** added a VS Code workspace file and practical source/test/build/branch/backup workflow. This groups existing sources and does not create, merge or move repositories.

New `server/tests/recoveredParity.test.js` verifies seed refusal, configured/missing OTP secret behavior, authenticated jobs/own/public/private profiles and scholarship filtering using an isolated database and local HTTP. No production data/schema/index migration occurred.

## Valuable work retained, not blindly merged

See `FEATURE_PARITY_REPORT.md` for feature-specific correctness, equivalents, tests and disposition.

- **Notification preferences:** genuine UI/API gap. Current Flutter calls category preference endpoints absent in the selected API. The old pending helper/model/routes/provider-filtering work is valuable but needs account-scoped client persistence, session-race tests and a decision about mandatory security/urgent notification delivery. A review patch is preserved; it is not an approved ready-to-apply migration.
- **Deferred story deletion:** potentially valuable latency/outbox experiment, but current atomic deletion/replay protection must not be replaced without current-API concurrency/crash/retry/media tests. Review patch preserved; not applied.
- **Old website destination/service search, sorting and forms:** potentially valuable behavior mixed with redesign/SEO changes. Preserve and separate behavior from appearance before approval; no broad old UI/dependency replacement.
- **Old Google setup context:** current website already uses `hasPassword` and has a password-setting flow; the old unconditional pending flag is not a safe replacement.
- **Claude/email/Wink historical branches:** their base commits are ancestors of the selected deployment HEAD; the relevant current features exist. This does not automatically include dirty deltas, which were reviewed separately.
- **Old flat core files/connected app prototypes:** many paths were relocated; prototype shells may contain modules needing manual review but should not replace the current session/transport/bootstrap. Old vulnerability-reproduction tests asserting overspend/overbooking are archival evidence, not correct acceptance tests.

## Deployment differences — VERIFIED COMPARISON, RECONCILIATION DEFERRED

`DEPLOYMENT_PARITY_REPORT.md` corrects the earlier interpretation of 150 differing hashes / 18 absent paths. Same-formatter snapshots leave **85 differing Dart files**, most involving braces, const, comments or deprecations. Of the 18 absent raw paths, **17 are generated/local/signing files and one is `test/story_deletion_test.dart`**. Native passport/backup-policy text and trust bundles compare equal after line-ending normalization.

Real remaining differences: optimistic story deletion/feed updates/rollback, immediate route removal, fullscreen viewer layout, Phase 1 viewer-list logout privacy fix, Material card surface fix and associated regressions. Authentication gates, session/transport API contracts, recent profile/passport/support/streak features are not all missing from deployment; inspected differences there are largely maintenance changes. The report gives an ordered feature-by-feature reconciliation plan. No deployment app source was overwritten or certified as interchangeable with fsfs.

## Validation — VERIFIED WITH RECORDED INITIAL FAILURE

Private logs: `.git/phase2-20261021`; machine-readable results: `PHASE2_VALIDATION.json`. Commands ran in the selected roots or the explicitly isolated website validation root with matching source/config/lockfile.

- `flutter pub get`: **exit 0**.
- `flutter analyze`: **exit 0**, no issues.
- `flutter test --reporter expanded`: **exit 0**, **439 passed**.
- `flutter build apk --debug --no-pub`: **exit 0**, APK built at `build/app/outputs/flutter-apk/app-debug.apk`. No new release APK or store certification is claimed.
- First backend `npm test` while Flutter was compiling/testing: **exit 1**, 241 passed / 2 failed / 0 skipped (243 executed). Both failures were MongoMemoryServer startup deadlines in `financialSecurity.test.js`; its early failed setup prevented additional assertions/subtests from running. This failure remains in `backend-tests.log`.
- Final complete backend `npm test`, run alone after Flutter finished: **exit 0**, **255 passed, 0 failed, 0 skipped**, 209 top-level tests, about 182.4 seconds. All three new recovery regressions ran. No assertions, lint rules or timeout settings were disabled/relaxed.
- Node syntax checks: **327 source/script/test files, 0 failures**, exit 0.
- Backend `npm audit --json`: **exit 0**, no reported known vulnerabilities.
- Website `npm test`: **exit 0**, **65 passed / 10 files**.
- Website `npm run build`: **exit 0**, TypeScript/Vite/SEO build completed. SEO generation may read its configured API.
- Full website audit: **exit 1**, still 15 affected package entries. Production-only audit: **exit 1**, 2 moderate entries. Compatible dry-run: **exit 1 due to remaining advisories**, 0 added / 0 removed / 0 changed. No Phase 2 package upgrade was necessary or forced.
- `git diff --check` passed for both selected repositories; JSON/workspace files were parsed and paths checked.
- iOS, physical-device performance, live production providers/database and exhaustive manual end-to-end behavior: **NOT TESTED**. Android's existing future Gradle/AGP/Kotlin support warnings remain.

The app/backend remain functional under executed regression/build checks. This does not certify every feature in production or the separate deployment app copy.

## Remaining security and dependency work — REQUIRES REVIEW

`PHASE2_SECURITY_REVIEW.md` maps every remaining package/advisory family to actual installed paths, development/production roles, current reachability evidence and required tests. The two moderate production entries are React Router; SSR hydration is not used by the current createRoot/BrowserRouter entry, while content-driven Link inputs still require navigation review. Remaining critical entries concern Vitest/Tinypool developer tooling, not a demonstrated production RCE.

The direct Vite is patched to 6.4.5 from Phase 1; remaining Vite 5.4.21 and esbuild 0.21.5 paths are nested test dependencies. Tailwind/parser/glob findings concern trusted-source build processing unless untrusted inputs are introduced. Do not treat reduced reachability as patching. npm's proposed React Router 7, Vitest 5 and Tailwind 4 updates are major migrations needing separate regression/visual/peer review; no blanket overrides or force updates were applied.

## Cleanup — REQUIRES EXPLICIT APPROVAL

Reverified the exact eight Phase 1 candidates: six matching-hash ZIP alternatives on C and two ordinary old Android intermediates directories on D. ZIP pairs still match. Generated paths have the same sizes, no nested links, signing keys, .env files, APK/AAB outputs or tracked original source. The selected source/caches/shared dependency owners are excluded.

Exact paths, hashes/retained counterparts, risks and instructions are in `FINAL_CLEANUP_APPROVAL.md`. Estimated logical recovery: **3,578,405,502 bytes (3.333 GiB)**, mostly 3.327 GiB on D. Physical NTFS recovery can differ. **No deletion was performed and no old source repository is proposed for deletion.** Approval must name all eight or a numbered subset; recheck state immediately before acting.

## Files changed specifically in Phase 2

Active application repository:

- `README.md` (links to the Phase 2 workspace/reports).
- `.vscode/StudyBirds.code-workspace`.
- `docs/FEATURE_PARITY_REPORT.md`.
- `docs/DEPLOYMENT_PARITY_REPORT.md`.
- `docs/FINAL_CLEANUP_APPROVAL.md`.
- `docs/WORKSPACE_WORKFLOW.md`.
- `docs/PHASE2_SECURITY_REVIEW.md`.
- `docs/PHASE2_FINAL_REPORT.md`.
- `docs/PHASE2_VALIDATION.json`.
- `docs/proposals/notification-preferences-review.patch` (review only).
- `docs/proposals/deferred-story-deletion-review.patch` (review only).

Selected backend repository:

- `server/src/utils/jwtSecret.js` (new).
- `server/src/utils/cashMisrSms.js`.
- `server/src/utils/whatsappOtp.js`.
- `server/src/routes/mobileSecurityRoutes.js`.
- `server/src/routes/alumniRoutes.js`.
- `server/src/routes/scholarshipRoutes.js`.
- `server/src/seed/seed.js`.
- `server/src/controllers/contentController.js`.
- `server/tests/recoveredParity.test.js` (new).

Phase 1 source/docs/lock/test changes remain uncommitted and preserved, not reclassified as Phase 2 recovery. Website source/manifests/lockfile were not changed in Phase 2. Final full Git status is retained privately with the checkpoint evidence; no branch, index or remote was changed to make the working trees appear clean.

## Next decisions

1. Approve an exact cleanup subset only if desired; the written request explicitly prohibits automatic external deletion.
2. Review notification policy and account-scoped persistence before authorizing its revised merge.
3. Review deployment parity units separately, especially privacy/card fixes versus fullscreen design; validate that app before a future release.
4. Review deferred server deletion and the UX-only historical changes before any port.
5. Schedule isolated major dependency migrations, Android toolchain maintenance, macOS/iOS validation and a private off-device backup.

No required high-risk decision was guessed. Safe recovered fixes are implemented and validated; uncertain work is preserved with concrete review material. The current paths and workflow remain stable without losing history or silently synchronizing old folders.
