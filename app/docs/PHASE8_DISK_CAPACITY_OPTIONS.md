# Phase 8 — read-only D: relocation options

Date: 2026-10-22. No files deleted, moved, compressed or modified except creation of this requested report. No cleanup script, build, installer, Git mutation or QA gate/configuration change.

## Result

**No clearly safe 1–2 GiB relocation set was found within the permitted scope.** D root contains only `work`, `flutter projects`, `$RECYCLE.BIN` and `System Volume Information`. The only immediate project under `flutter projects` is excluded Quantis. Protected repository/worktree roots and QA resources were pruned before traversal, as were backups, dependency caches, active build outputs and browser profiles that may contain credentials. Links were not followed. No eligible large downloads, temporary archives, installers or duplicate non-protected artifact set was discovered. No access errors occurred in the permitted traversal; excluded contents were intentionally not inventoried.

Free-space snapshot before discovery: **7,833,157,632 bytes (~7.295 GiB)**. At this snapshot, the gap to 8 GiB is **756,776,960 bytes (~721.72 MiB)**; the gap to 10 GiB is **2,904,260,608 bytes (~2.705 GiB)**. Capacity varies with unrelated activity; remeasure before making a later decision.

## Metadata-only owner review leads — not approved relocation candidates

1. **`D:\work\.studybirds-security-backend-release.log`**
   - **316,222 bytes (~308.81 KiB)**; `.log`, last modified 2026-10-17 UTC.
   - ACL owner: `DESKTOP-BI43VHU\Abood`; ordinary file, one hard link reported, no reparse attribute.
   - Ownership uncertainty: filesystem owner is known, but who currently needs it, retention requirements and whether it contains credentials/personal data are unverified. Contents were not opened or printed. It might be important audit evidence rather than disposable output.
   - Relocation requires **separate exact-file owner approval**, retention/sensitivity review and an approved destination. No claim that it is inactive or safe to move.

2. **`D:\work\.studybirds-mobile-audit-release.log`**
   - **16,694 bytes (~16.30 KiB)**; `.log`, last modified 2026-10-17 UTC.
   - ACL owner: `DESKTOP-BI43VHU\Abood`; ordinary file, one hard link reported, no reparse attribute.
   - Same uncertainty: operational ownership, retention, contents and active use were not established. Contents were not opened or printed; audit/recovery value is possible.
   - Relocation requires **separate exact-file owner approval** and the same review. Not recommended as a meaningful capacity solution.

Combined logical size: **332,916 bytes (~325.11 KiB, 0.00031 GiB)**. No physical reclaim is guaranteed or counted. Even relocating both would be immaterial and would not meet 8 GiB. No duplicate claim was made: content comparison would require reading files, which was unnecessary for these unsuitable leads.

## Protected exclusions

- Quantis entirely.
- Every detected/known Git repository or worktree, including the `D:\work\studybirds_app` wrapper itself (a `.git` entry is present), source code, patches and source-recovery inventory.
- Entire `D:\work\studybirds_qa_phase7`, databases, storage, TLS/credentials and QA evidence.
- APK/AAB deliverables, signing keys/certificates, environment files, backups/checkpoints, dependency owners/caches and generated build directories.
- Five `.studybirds-email-*` browser/session profile directories: excluded because session cookies/credentials may exist; their contents and sizes were not investigated as relocation options.
- Windows system/recycle directories: no traversal, contents inspection or cleanup proposal.

## Decision

There is no supported relocation recommendation in the discovered scope that reaches the desired additional capacity. Do not expand this finding into permission to relocate repositories, backups, browser credentials or Quantis. More capacity requires a separately scoped owner decision, such as providing additional drive capacity; this report authorizes no disk or development changes.

**QA APK compilation/assembly remains unauthorized.** No gate was changed and no build was attempted.
