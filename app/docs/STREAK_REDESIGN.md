# Streak redesign — implemented locally, not deployed

## User-facing changes
The authoritative app now displays My Streak / سلسلة نشاطي immediately beneath the private student profile header (my_streak.dart). Student Community/story feed no longer mounts restoration prompts. Public student profile no longer displays consecutive-day counts. Rewards and the legacy points sheet retain points/tasks but no longer duplicate streak flames/recovery controls. No navigation tab added.

Private card and scrollable details sheet support Arabic/English, RTL/LTR, ambient light/dark color schemes, narrow phones/tablet widths, large text and safe-area padding. Summary covers active/at-risk/recoverable/fully expired/empty/loading/offline/error states. Details show longest recorded streak,35-day server-calendar history, monthly allowance, exact UTC-labeled server deadlines and countdown. Small count transition honors reduced-motion preferences. Restore has a separate confirmation sheet, single in-flight action, success feedback and immediate profile updates; exhausted allowance shows the server reset date without purchase options. Account changes clear private data and reject late responses; resume and activity notifications refresh state.

## Server rules and compatibility
Existing36h expiration with24h warning is preserved. Recovery is allowed ONLY during the next24h after that expiration. Exactly3 successful restorations per student per server calendar month, default Europe/Istanbul; no carryover. Monthly reset does not reopen an expired recovery window. Restore endpoint uses the existing MongoDB transaction pattern; allowance, stats and new durable per-user operation ledger commit together. Failed requests do not charge; duplicate operation keys remain free across later expirations. Legacy requests without a key remain accepted subject to eligibility/atomic limits. Client timestamps never determine eligibility.

Progress API fields retained; additive fields include serverNow, serverDay, streakState, recoveryExpiresAt, monthResetsAt, longestStreak and activityCalendar. GET /stories/streak/details streams the current student's retained historical stories to reconstruct known best/history without rewriting/deleting old data. Post/restore/lazy expiry maintain longestStreak; real posting adds calendar dates, restoration does not invent activity. Already-deleted historical data cannot be reconstructed or fabricated. New optional schema fields preserve old counters/points. New indexes: Story(author,createdAt) and unique StreakRestoration(user,operationId).

Countdown uses a server snapshot plus monotonic elapsed time, never the device wall clock. Old server payloads lacking trusted server timing do NOT enable restore; history unavailability is distinguished from a new account. A404 on the new details endpoint falls back to legacy progress. This preserves a safe usable profile while waiting for backend rollout.

## Validation actually run
- Full Flutter suite462 passed. After final RTL/legacy-display refinements,32 relevant Flutter tests passed again.
- One additional visual-render test passed using actual widgets with synthetic data, real Tajawal/Material fonts; Arabic light and English dark PNGs reviewed. No private real account captured.
- Final flutter analyze: No issues found.
-13 backend tests passed with isolated temporary MongoDB replica sets, installed cached binary, downloads disabled and external-network test guard. Covered exact36h/60h boundaries, calendar-month timezone reset, fourth refusal, duplicate/concurrent requests, durable replay, failed-window/invalid-key noncharging, role/owner privacy, historical activity and story/viewer regressions.
- Normal authoritative debug APK rebuilt successfully; Android signature v2 and zip alignment verified. New confirmation UI found inside compiled APK; credential-pattern scan found0. Pattern scan is not an exhaustive security proof. No phone/emulator launch test.

## Scope and preservation
Original scoped files backed up and original hashes verified at C:\Users\Abood\AppData\Local\StudyBirds\streak-redesign-20261022\BEFORE.json; BEFORE_AFTER.json and VALIDATION.json record final results. Prior unrelated local changes retained; no commit/reset/stash/push, deployment, live QA process restart, production DB change, signing change, security-gate bypass, B0 or workspace migration. Existing API23368/Mongo21696 creation identities and QA Android gate remained unchanged. Existing APK delivery retained; new APK has a different filename.

## Release boundary / remaining limitations
Backend changes are LOCAL only. A separately authorized backend release must create/verify the new indexes before exposing the new contract. Roll out backend before mobile for complete history/recovery. Until then, hosted old APIs show available progress but cannot authorize new recovery UI; no unsafe local fallback. Real-device Arabic/iOS/Android permission, app-resume and authentication smoke checks remain required. Widget tests establish layout/theme compatibility, not verified iOS device execution. Existing global app theme selection is unchanged; new components follow the supplied ambient theme.

New APK: D:\work\StudyBirds-APK-Delivery\StudyBirds-Streak-Test.apk
Evidence and synthetic previews: C:\Users\Abood\AppData\Local\StudyBirds\streak-redesign-20261022
