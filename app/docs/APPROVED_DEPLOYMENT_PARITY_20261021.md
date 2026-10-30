# Approved deployment-app reconciliation — 21 October 2026

The owner explicitly approved patches **01, 02, 03 and 05 only**. They were applied to `D:\work\studybirds_session_release\app` after fresh preservation, source/proposal hash verification and a combined `git apply --check`. Patch **04 (fullscreen story layout) was not applied**. No commit, push or deployment was performed.

## Applied behavior

- 01 clears private viewer names/counts/cursors after logout and ignores late responses.
- 02 supplies a Material surface to ordinary and tappable AppCards.
- 03 coordinates optimistic deletion with the feed, deduplicates repeated deletion, restores failed requests and removes the exact viewer route immediately.
- 05 uses authenticated account preferences, isolated local keys, confirmed writes/rollback/retry and session guards. Mandatory security/authentication/urgent delivery remains outside optional category muting. The matching backend endpoints remain local work from prior stabilization; this step did not deploy them.

The old card/contain story viewport is intentionally retained. Actual target files match the previously tested no-fullscreen private variant across 528 source entries. Backend, website and unrelated deployment files match their new pre-application checkpoint. No authoritative Flutter production source was changed by this reconciliation.

## Preservation and boundaries

Before applying, `.git/approved-parity-20261021/app-final` and `deployment-final` captured 552 and 1,163 files respectively, SHA-256 verified, with statuses, HEADs and binary diffs. These folder names refer to the checkpoint script's labels; for this operation they are the **pre-application** recovery points. Existing checkpoints were not overwritten. Checked deployment-local signing/property paths had no files requiring a new private copy; no signing/environment file was created or modified.

Git HEADs/history/indexes and existing worktree relationships remain unchanged. Applied patch hashes/check/apply results are recorded privately in `applied.json`. Generated pub/test files are local tooling output, not additional business-source patches. Nothing was deleted, moved, archived, committed, pushed or deployed.

## Validation

Commands run explicitly from `D:\work\studybirds_session_release\app` using `C:\src\flutter\bin\flutter.bat`. `flutter pub get` exited 0; `flutter test --reporter expanded` exited 0 with **444 passed, 0 failed**. The count is one below the full five-patch variant because the fullscreen-only test is intentionally absent. Private logs: `.git/approved-parity-20261021/deployment-pub-get.log`, `deployment-analyze.log`, `deployment-tests.log`.

`flutter analyze` returned exit 1 with **279 informational diagnostics, 0 warnings and 0 errors**. Of these, 276 are in byte-identical unchanged files; the other three point to lines already present in the pre-application source. They concern existing const/braces/deprecation maintenance. No diagnostics or rules were suppressed and no SDK-maintenance patch was added outside the approved scope. Details are retained in `analysis-details.json`. This is not a clean-analysis result.

No fresh deployment APK, signed release, backend/website suite or real-device/provider test is claimed in this step. The previous Phase 3 backend/website results remain historical evidence, since their source was unchanged. The authoritative Flutter's earlier clean analysis does not imply the separate deployment copy is lint-clean.

Machine-readable follow-up results are appended to `PHASE3_VALIDATION.json`. A separate SHA-256 verified post-application checkpoint is retained under `.git/approved-parity-20261021/post-application`; the pre-application recovery points remain separate.
