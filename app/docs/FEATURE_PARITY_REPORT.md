# Feature recovery and parity review — Phase 2

21 October 2026. Existing Phase 1 inventory was reused; no full-drive rescan was performed. Old copies were read, not reset, staged, stashed, committed or modified. Current source candidates remain the Flutter fsfs checkout and the server/client in `studybirds_session_release`.

## Important dirty repositories

- `D:\work\studybirds_app`: an **older parent repository**, branch `abood-changes`, also tracking files physically inside the independent active app repository. Phase 2 initial `git diff HEAD --name-only` returned 312 paths. Its staged application modernization largely points at the same physical current app, not a second independent source copy. Do not stage/reset the parent to consolidate the nested app. Its server-only security/logging/seed changes were evaluated below and selectively recovered; its index and original files remain untouched.
- `D:\work\studybirds_islam_google_password_fix`: `fix/islam-google-password`, 104 changed tracked paths versus HEAD at Phase 2 start. Includes website presentation/filter/form changes, Google setup flow, notification delivery preferences and two route/query fixes. Whole-folder copying would regress current API/session/security work. Preserve the copy and its untracked helpers/tests.
- The requested underscore path `D:\work\studybirds_stories_release` does **not** exist. The actual previously inventoried worktree is `D:\work\studybirds-stories-release`: detached `a5b118a`, three tracked pending files implementing deferred story deletion. Its exact patch is retained for review and not applied.
- `D:\work\studybirds_web`: nine pre-existing staged status entries: a nested `monorepo` gitlink and generated Android Gradle cache files. These are not evidence of a missing business feature. Do not unstage or remove them automatically. This repository also owns Git worktrees and dependencies used by the active source.

Captured initial statuses/diff summaries are private under `.git/phase2-20261021`. Counts are Git paths, not missing-feature counts. Untracked work is preserved in place; the old repositories were not silently backed up wholesale or changed.

## Reviewed recovery decisions

### OTP secret handling — RECOVERED

The parent's `server/src/utils/jwtSecret.js` and three call-site changes replace the public `'dev'` HMAC fallback with an explicit required `JWT_SECRET`. The selected API previously still had that fallback in mobile-security email codes, CashMisr SMS and WhatsApp OTP helpers. Other token generation already required a configured secret, so this is a configuration-failure correction, not a rotation or production configuration change.

Recovered a small shared helper and the three call sites. Configured secrets produce byte-identical digests; missing/empty configuration now throws before creating a predictable digest. New tests verify configured SMS/WhatsApp digests and missing-secret refusal. No secret values are reported.

### Destructive seed guard and contact logging — RECOVERED

The parent's seed guard refuses destructive development seeding in production; the selected script lacked the guard. Recovered the guard immediately after dotenv and **before database/model imports**. A subprocess test uses `NODE_ENV=production` and a temporary working directory and verifies refusal; it does not connect to a database or seed data. The script's unrelated existing development connection/import compatibility is not repaired as part of this safety change, and development seeding was not executed.

The parent's removal of contact-recipient/from-address logs was also absent in the selected API. Removed those two configuration-value logs while retaining safe operational error handling. API response behavior is unchanged.

### Alumni job route shadowing — RECOVERED

The older Google-password worktree moves `GET /:userId` behind named alumni routes. The selected router had `/:userId` before `/jobs`, so requesting job listings was treated as an invalid user ID and returned 404. The Flutter alumni/job UI already calls the named route, so this is an existing-feature bug, not a new endpoint.

Moved only the wildcard block. Real local MongoDB/HTTP regression coverage checks unauthenticated denial, authenticated job listing, own profile, public profile and private-profile denial. The current validation and authorization code was preserved.

### Scholarship field filter overriding expiry — RECOVERED

The selected list's availability query used `$or` for null/future deadlines, then replaced that same `$or` when a field was supplied. The older pending patch correctly ANDs field matching with availability. Recovered that narrow query change. A regression creates active/future, active/expired, inactive, no-deadline and unrelated-field records; filtering returns only the open matching scholarships. No stored data or schemas were migrated.

### Notification category preferences — VALUABLE, REQUIRES REVIEW/APPROVAL

Both current Flutter copies call `/mobile-security/notification-preferences`, but the selected API has no such GET/PUT routes or User preference field. The old Google-password worktree contains a validated category helper, additive User Map, authenticated GET/PUT and push-recipient filtering. It is a genuine API/UI gap, not a renamed file.

The proposed original patch is saved at `proposals/notification-preferences-review.patch`, **not applied**. It needs adaptation to the current router; it is a review artifact, not a guaranteed clean/applicable patch. The old mock-heavy `webParity.test.js` does not establish real MongoDB, session-switch or provider compatibility.

Before approval/implementation: decide whether security/urgent notifications may be muted; replace title/body regex classification with explicit categories where practical; scope Flutter's currently device-wide preference keys to the account; protect against logout/account-switch races and failed remote writes; test defaults, unknown/invalid fields, authorization, persistence and individual/group sends using real isolated storage and mocked provider calls. Restoring only the UI or only filtering provider sends would give misleading behavior. No broad delivery-policy change was made automatically.

### Deferred story deletion — VALUABLE EXPERIMENT, NOT APPLIED

Three pending files in `studybirds-stories-release` change synchronous transactional deletion into one soft-delete write followed by worker cleanup. The selected API already prevents reward replay and deletes interactions/media references transactionally; the selected Flutter app already hides deletes optimistically and restores them on failure.

The old patch can reduce server delete latency but changes transaction/outbox semantics. It retains text/media until maintenance, resets cleanup state on repeat requests, and needs concurrent delete/love/seen, worker crash/retry, delayed media deletion and no-point-farming tests against the current viewer API. Saved at `proposals/deferred-story-deletion-review.patch`; preserve the old copy and request approval after a reviewed revised patch. The older single added test assertion is insufficient to certify these semantics. No database/index changes or production worker changes were made.

### Google password setup and 2FA — EQUIVALENT CURRENT FLOW; DO NOT REPLACE

The old worktree's AuthContext sets a pending password-setup flag on every Google login. Current website `LoginPage.tsx` already branches on `user.hasPassword` and implements setting a password; current Flutter onboarding has its password/email verification gate. Replacing them with an unconditional old sessionStorage flag would misclassify existing accounts. Current authentication/security tests provide stronger evidence than the presence of an old flag. Preserve historical work; do not port the old context wholesale.

### Website destination/service search and reusable forms — PRESERVE FOR PRODUCT REVIEW

Old pending `StudyDestinationsPage.tsx` adds search, sort by university count, empty/retry states and a new hero. The current page keeps different SEO copy/layout and fetches countries without those controls. Old `ServicesPage` and `FormInput` work similarly combines behavior with broad presentation changes. These are potentially valuable UX changes, not required security fixes. Keep the old code; an approved port should separate search/retry behavior from redesign, retain SEO/translations, and add loading/error/search/sort/keyboard-accessibility tests. No old styling or dependency manifest was blindly restored.

### Claude provider, email branding and Wink branches — ALREADY INCORPORATED HISTORY

Read-only ancestry checks show `c1ae0df` (Claude), `aac8419` (email branding), `e0aff5b` (Wink), `4fed84c` (Google-password base), `a5b118a` (stories base), `a1da3390` and `a6f72263` are ancestors of the selected deployment HEAD. The selected `assistantProvider.js` includes the Anthropic adapter alongside other providers. Historical ancestry proves the commits are present, not that all pending changes are present: dirty deltas were reviewed separately above. No branch was deleted or cherry-picked.

### Flat core paths, connected prototypes and old downloads — ARCHIVE/REVIEW

Most copy-only old `lib/core/foo.dart` names have current counterparts under `core/repositories`, `services`, `utils`, `widgets` or `config`. The inventory-to-source lookup found 99 such matches across repeated old roots. This is relocation evidence, not proof that the implementations are equal.

The old `ConnectedApp` / `WorkspaceHome` / generic `StudyBirdsApi` prototype is a separate application shell with dynamic workspace modules. Current role-specific dashboards, shared `ApiClient`/`AuthSession`, private-document handling and refresh behavior replace much of its purpose. Restoring its bootstrap/transport would duplicate session ownership and risk security/API regressions. Preserve prototype source and tests; any business module without a verified current equivalent remains a manual feature-review item, not automatically obsolete.

The old `auditFindings.test.js` deliberately asserts vulnerable wallet overspending/overbooking behavior and uses timing barriers. Current financial/concurrency suites assert the corrected boundaries. Archive it as a historical reproduction; never import those vulnerable expected results as acceptance tests. Old package names/native example activities and generated iOS Swift package paths in Downloads are not missing application features.

## Test gaps and limits

New `server/tests/recoveredParity.test.js` covers the actually recovered security/routes/query/seed behavior. Critical uncertain work remains preserved with review patches and explicit test requirements. This phase does not claim every experimental module or every historical archive is semantically equivalent; it prioritizes the dirty/unique work identified in Phase 1 and avoids declaring unexplained differences safe to delete.
