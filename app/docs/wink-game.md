# الغمّازة / The Winker

Entry: the dedicated Winker tab in the bottom navigation. No game entry remains in Services.
Visual design: selected concept 08, Sky Clean. Sky blue backgrounds, static cloud
decoration, navy text, white panels and orange primary actions are shared by the
hub, lobby, private cards, voting, results and game-only bottom navigation.
Players use their existing profile image or a bundled four-avatar sprite sheet.
The horizontal roster preserves player order and scrolls for larger groups and
large text. Game dialogs inherit the light palette independently of the app theme.

Avatar artwork: `assets/images/games/wink_avatars.png`, generated using the built-in
`image_gen` tool with transparency. The sheet is cropped into four avatars by the
Flutter widget at display time; no additional image package is required.
Generation prompt:

> Use case: stylized-concept. Create ONE production game avatar sprite sheet for the selected Sky Clean Study Birds mobile app. Square transparent PNG, EXACTLY 2 columns x 2 rows of four evenly sized avatar busts. Each avatar centered at the exact center of its equal quadrant with generous clear transparent spacing and contained within a circle that occupies 80% of the quadrant width. No visible circular frame or background: transparency surrounds each person. Four charming polished 3D clay-style young adult student avatars, front-facing head and shoulders, smooth friendly faces, elegant professional mobile casual game quality: top left short dark wavy-haired young adult man blue hoodie, top right young adult woman long brown wavy hair orange shirt, bottom left young adult man curly brown hair round black glasses teal shirt, bottom right young adult man neatly styled dark hair blue jacket. All are adults, expressive warm smiles, soft studio illumination, vibrant sky blue orange teal clothing. No text, numbers, logos, borders or UI. No props. Avoid cropping hair or shoulders, no heads crossing quadrants. This is an RGBA game sprite sheet asset with genuine transparent background.
Gather at least four players in the same place, each signed in on their own phone. Create a room, share/copy
the eight-character code, join, mark everyone ready, then let the host start.
Hold to reveal your role and confirm it. The wink happens in real life, followed by voluntary self-reporting.
Internet is required only to synchronize room state, cards and votes.
Code entry accepts Arabic/Persian/English digits, lowercase letters and pasted separators.
Rounds, role confirmation and voting have no time limit. There is no wink cooldown.
The round ends by finding the winker or when only two players remain; votes finish
once every eligible living player has voted (yes, no or abstain).
There is no digital-wink mode.
No camera or eye detection is used.

## Single-device practice

Choose **Try with 3 bots** in the game hub. A private server-managed training
room starts with your account and exactly three simulated players, already
ready. Hold your card and confirm it to begin. Bots wink, accuse and vote on
server timers. Practice does not create user accounts and cannot be joined
or shared with other humans. The owner still needs the usual API connection.
After the result, choose another player round or **Try as the winker**. Only
that private practice room offers the **Practice wink** button; real rooms
continue to use real eye contact. Practice closes when its owner leaves or
their reconnect grace expires. A lone host can also switch from an empty
lobby to private practice using its dedicated button.

## Implementation

- Flutter: `lib/screens/games/wink_screen.dart`, `wink_controller.dart`.
- Backend: `server/src/games/winkEngine.js`, `winkStore.js`,
  `models/WinkRoom.js`, `routes/winkRoutes.js` in the web/server repository.
- Uses existing JWT sessions, Express, MongoDB and foreground polling.
- Polls the current room every two seconds while foregrounded. A server-side
  one-second sweep resolves deadlines even if every phone stops polling.
- Each room update uses a MongoDB revision compare-and-swap, including
  duplicate action receipts. Requests are authorized before projection.
- The API returns explicit public fields and only the caller's private role,
  notice and ballot. It excludes pending victims and reveals the winker only
  at the result. Private responses bypass the general idempotency response
  cache; action replay is handled inside the room transaction.
- A lost action response is retried using the same operation ID. Actions are
  disabled while offline or pending. Reconnection grace is 60 seconds, independently
  of the untimed game; already accepted winks retain their short elimination delay.
- Existing WhatsApp sharing via `url_launcher` is reused; copying is available.
- Arabic/English text and direction follow the app locale. Audio and haptics
  default off; long-press opens a role card until the player taps Hide card.
  Cards also hide on background, tab changes and new rounds. Background polling
  keeps action buttons available and ignores reads superseded by an action.

## Running

No new external service, API key or package is required. Start the existing
backend with `npm start` from `server`; MongoDB must be configured as usual.
The normal server entry point starts the deadline scheduler. If embedding
`app.js` in a different process, call `startWinkScheduler()` once after MongoDB
connects. MongoDB creates the room collection and indexes via the existing
Mongoose configuration. Room cleanup uses a 24-hour TTL after closure.

Run Flutter using the project's pinned SDK:

```powershell
C:\Users\Abood\flutter\bin\flutter.bat run
```

Use `--dart-define=API_BASE_URL=http://10.0.2.2:5000/api` for an Android emulator
talking to a local server. Physical phones need an address they can reach.
The regular release configuration uses the existing Render API.

## Validation

```powershell
flutter test test/wink_game_test.dart
flutter analyze lib/screens/games
node --test server/tests/winkEngine.test.js server/tests/winkRulesBounds.test.js server/tests/winkIntegration.test.js server/tests/idempotency.test.js
```

Integration tests use the project's existing `STUDY_BIRDS_TEST_TOOLS`
MongoMemoryServer setup and optional `MONGOMS_SYSTEM_BINARY`. They run four
authenticated players against an actual HTTP server and MongoDB, including
matching the created code and host for all four accounts, isolation from another
host's room, lowercase/Arabic/Persian code entry, repeated joins, simultaneous
room writes, duplicate self-reports, concurrent accusations, votes,
privacy, and a new-round reset. Flutter tests cover role concealment,
disconnection, action retry, English/Arabic and large text on a 320px screen.

Device sound/silent behavior and a human face-to-face session still require
manual testing on real phones. Polling delivers updates within about two
seconds under normal connectivity; no WebSocket service is required.
