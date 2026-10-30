# Phase 5 ? storage recovery preparation and release blockers

21 October 2026. Completed scoped preparation; no destructive cleanup or migration performed. Read Phase 4 final report/validation, updated readiness and migration proposals; preserved their historical results.

## Storage

Initial D free: 1,089,703,936 bytes (1.015 GiB). Latest observed during validation: 1,078,763,520 bytes (1.005 GiB). D has roughly 22.5 GB used on a small volume. Scoped directory inventory did not follow junctions. Largest reviewed contributors include two Android build trees (~6.62 GiB combined), parent Git metadata (~3.89 GiB), protected checkpoints/dependency evaluations, older retained projects and caches. This is storage attribution, not permission to remove those folders.

Eight exact nonoverlapping generated candidates total 6,396,233,840 bytes (5.957 GiB). See [numbered cleanup proposal](PHASE5_CLEANUP_APPROVAL.md). Logical sizes are estimates; actual reclaimed space is **0 bytes from cleanup**, because nothing was deleted. Gradle daemon activity/handles must be resolved before any approved cleanup; APK deliverables, source, signing, configs, Git, checkpoints and shared dependency targets are excluded. Test-cache sizes can change during validation.

## Flutter remediation

Actual deployment analysis confirms 279 ? 275 informational diagnostics, zero warnings/errors. Four local behavior-preserving fixes: three redundant import removals and one early-return brace block. Verified recovery copies before each edit. Targeted actual-deployment tests: **22 passed**, exit 0. Full analysis inventory and rule/file/line/risk/fix guidance: [remediation](FLUTTER_ANALYSIS_REMEDIATION.md). No full build, package installation, broad reformat or lint suppression. Fresh Dart machine analyze returns exit 0 for info-only results; that is not a clean Flutter lint pass.

## Security migration state

React Router 7.18.4 was separately approved and completed BEFORE Phase 5. Do not replay it or downgrade it: actual installed Router remains 7.18.4. Its prior isolated and actual tests (100) and builds passed; historical production dependency audit had 0 known findings, full audit 13 development-tool entries. No fresh security audit or dependency installation was run here. The isolated strategy, exact lock diff, source/checkpoint hashes, negative controls and recovery boundaries are retained in REACT_ROUTER_UPGRADE_20261021.md, REACT_ROUTER_VALIDATION.json and proposals/phase4/SECURITY_MIGRATIONS.md. Runtime candidate/node_modules remains active and protected. Reversal would require separately reviewed individual manifest/lock/test restoration plus coordinated junction retargeting using preserved dependencies; do not reset Git or delete candidates.

Vitest and Tailwind major migrations still need separate approval and isolated tests. Tailwind also needs a browser-support/visual decision. Fullscreen patch 04 remains unapproved. No major migrations applied in this phase.

## Android QA blockers

[Device plan](ANDROID_DEVICE_QA_PLAN.md) requires adequate disk space, explicit isolated QA API/database/storage/accounts, provider isolation and a freshly built QA-specific debug APK. Existing APK defaults to hosted API. Hard-coded push/Google configuration means API_BASE_URL alone cannot establish full isolation. Debug Sentry can stay disabled; release uses configured DSN. No production credentials/database/endpoint/provider was used, and no device QA pass is claimed.

## Preservation and boundaries

Source preimages, hashes, before/after analyzer inventories, focused test logs and pre-change Git states/worktree lists are under private .git/phase5-20261021. Previous checkpoints remain. Changed source files are only the four scoped deployment-app files; primary Flutter source, website, backend, authentication/API contracts, signing configs, dependency links, Git histories/indexes and worktree relationships are unchanged. New repository documentation comprises the four requested files. No deletion, reset, stash, commit, push, deploy, repository move or production mutation.

Before further action: owner approves exact cleanup IDs after review; fresh idle/link/content checks precede deletion. Approve provider-isolation implementation scope and remaining independent major migrations separately. Publishing remains unapproved.
