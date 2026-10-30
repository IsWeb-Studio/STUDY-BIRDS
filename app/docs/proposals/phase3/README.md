# Deployment application reconciliation — approved subset applied

Follow-up: the owner approved 01/02/03/05, which are now applied to the actual deployment app. **04 remains unapplied.** The descriptions below record the reviewed pre-application differences. See [the application/validation record](../../APPROVED_DEPLOYMENT_PARITY_20261021.md). Do not replay the four applied patches onto the modified target.

21 October 2026. Target: `D:\work\studybirds_session_release\app`, inside deployment HEAD `e9060536e8dc7a70150da9c42d6dfac901713553`. Source of reviewed behavior: authoritative fsfs app, HEAD `3e31e19c5343170056e6d7559c59bfb891f2c624` plus preserved local changes. These patches do not contain signing files, environment files, generated Android/iOS configuration or dependency changes.

## 01 — Private story viewers

Current deployment can retain viewer names/counts/cursors after logout. The authoritative implementation clears them, unregisters its listener and ignores late pages. This is the correct privacy behavior. Patch includes its logout regression; owner-only server authorization and pagination remain unchanged. Low compatibility risk, no API change.

## 02 — Material card surface

Deployment only provides a local Material surface for cards with onTap. Descendant ListTiles/switches in ordinary cards can therefore fail Flutter ink-surface assertions. The authoritative implementation provides the surface to both variants, preserving spacing and decoration. The patch is confined to AppCard. Validate existing profile/design/widget tests; low risk with appearance checked manually.

## 03 — Optimistic deletion, feed updates and rollback

Deployment waits for DELETE before closing the viewer and has no shared hidden/pending state for the feed. The authoritative implementation hides a pending deletion, deduplicates requests, removes the exact viewer route immediately, restores the feed on failure and provides retry. Patch transfers the repository/feed/deletion logic and its regressions while retaining the deployment card-style media layout. Existing API DELETE/authorization/rewards semantics are unchanged; the old deferred server deletion experiment is excluded.

This is a coordinated functional unit, not three independent file fixes. Risk is medium: test dialog route ownership, rapid repeated taps, concurrent refresh, failed DELETE rollback and account switching. Immediate local disappearance does not mean the server deletion is confirmed.

## 04 — Fullscreen story layout

Depends on 03. Changes media from the older constrained card to the authoritative full viewport/cover fit with repositioned overlays and controls. Neither layout is inherently a security correction; the authoritative design is the current selected product implementation. Risk is visual/interaction regression, especially portrait/landscape cropping, small screens, video and gesture targets. Includes existing fullscreen/gesture/control regressions. Requires explicit design approval and manual device review. It is separate so 03 can be accepted without changing the viewport.

## 05 — Account notification preferences

Deployment still uses unscoped device keys and lacks confirmed-write/late-session protections. This patch transfers the account-scoped store, UI, scheduler integration and six preference tests. Requires the newly implemented backend preference endpoints in the same future release. Optional categories may be muted; security/authentication/urgent notices bypass category muting. OS/provider permission limits remain. Existing in-app history/email behavior is unchanged. Risk is medium across offline/session/local-scheduling paths; background cross-device cancellation of already queued reminders is not introduced.

## Applying and validation

All files are review artifacts. None was applied to the real deployment app. Sequential `git apply --check` and application succeeded against a private copy of the exact deployment app. Use order 01, 02, 03, 04, 05 when reviewing the complete series; 04 requires 03. At application time, recheck target hashes/Git state and `git apply --check` rather than forcing a patch onto changed source.

Private validation roots are under `.git/phase3-20261021`, not new authoritative repositories. Results, commands and limitations are recorded in `docs/PHASE3_VALIDATION.json` and `docs/PHASE3_FINAL_REPORT.md`. Fullscreen approval is independent of the privacy/card fixes. No commit, push or deployment is authorized by these artifacts.
