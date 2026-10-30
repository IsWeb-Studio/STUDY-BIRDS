# Shared Community and Streaks Across Accounts

## Existing architecture reviewed

The mobile app presents the same community hub from the student app shell and the parent, university, and employee dashboards. The hub combines community conversations with the shared feed. The agent dashboard does not expose that hub. The backend protects community and story routes with authenticated role allowlists; agent/partner roles are excluded, while the existing administrator access and moderation paths remain intact.

Community posts and comments are stored separately and refer to their author by user ID. The public feed populates only the author's name, avatar, role, and—when the author is a university login—the linked university's public name and logo. It does not expose account email or other private profile fields. Community suspensions and moderation status are enforced by the API, so hiding write controls in the app is only a usability measure.

`StoryStats` already stores streak data per user. Students earn their story streak from their own stories; parent, university, and employee accounts use the online game activity fields. Eligibility, expiry, restore allowance, and server calendar boundaries are computed by the API. The game route calls the reward function after an accepted game action. Background room reads and status polling do not count as activity. The existing monthly restore rules and agent exclusion are unchanged.

## Changes in this extension

- Added community post editing, comment editing, and like/unlike controls. The API checks ownership, role authorization, suspension state, content limits, and blocked terms. Likes use a separate unique `(post, user)` edge, so retries do not duplicate a person's reaction.
- Added account-scoped community notifications for new comments and likes. These respect the recipient's community notification preference; the app now exposes that category in notification preferences.
- Added localized role labels and verified university identity display. Other community roles show their own account name/avatar and a role badge.
- Localized the community feed, compose/filter flow, post thread, editing and reporting UI in Arabic and English, with layout direction following the selected locale.
- Localized the shared story composer, viewer controls, viewer list, and community hub in Arabic and English; the student-only story-points task remains hidden from other roles.
- Tightened online-game streak crediting so reads, lobby activity, practice sessions, bots, and single-player rooms do not create a game streak. Real accepted actions in a room with at least two human players remain eligible.

## Safety and compatibility

The community write APIs remain authenticated and use role checks. Agent/partner access remains excluded. Administrator access and employee moderation remain as previously configured. University identity comes from the linked catalog record, not a client-supplied label. Streak state remains per authenticated user and server-authoritative. No production service, database, provider console, credentials, or deployment was changed as part of this work.

The reaction collection is additive and has a unique compound index. Its first like request ensures that index exists before writing. Existing posts, comments, story records, and streak histories are not rewritten. Community notifications are best-effort product events and obey each recipient's saved preference.

## Validation

Flutter analysis passed for all 27 targeted source and test files. The combined role, community, streak, notification, story playback/viewer/deletion suite passed all 86 tests. This includes four-role account entry points, agent exclusions, Arabic and English story/community labels, ownership edits and likes, streak restoration, account-scoped notifications, and existing story playback behavior.

Backend syntax checks passed for all 11 changed route/controller/model/reward/notification/test files. All six isolated streak-restoration tests passed, as did direct checks for community notification classification and the mandatory security/urgent categories. Community and game API integration tests are present, including role access, ownership, reactions, notifications, and poll-versus-action streak credit. They could not be executed here because the configured `mongodb-memory-server-core` test tool is unavailable and `STUDY_BIRDS_TEST_TOOLS` is not configured; no package was downloaded and no configured database was used.

No APK was built and no service was deployed.
