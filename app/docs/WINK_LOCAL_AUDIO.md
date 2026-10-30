# Winker: one-device play and game feedback

Implemented on 2026-10-23 in the actual Winker hub.

- The one-device entry now opens a local pass-and-play game for **4–11 real people**. It starts with four name fields; each player reveals and hides their own card before passing. Backgrounding hides the card and voter controls. One random winker, unique cards, self-reported eliminations, one accusation per living player, sequential private votes, strict majority and both win conditions are implemented. No server rooms, persistent roles, account impersonation or rewards are created. The existing server practice protocol remains compatible for already-open training rooms but has no solo hub entry.
- A visible **Game rules / قواعد اللعبة** button replaces the help icon. It fits narrow screens and large text. Local play has its own rules and sound controls.
- Recover my room now disables during requests and explicitly says when no active room exists. Existing account rooms still load from the authoritative server; local shared-device games are intentionally temporary.
- Six original bundled PCM WAV effects cover dealing, card reveal, elimination, vote, finish and private notice. Playback uses the existing video_player dependency's asset/audio support; no additional plugin or remote audio is used. Sound and haptic preferences are independent, preview immediately, persist, and remain off by default. The controls label now describes actual game effects.
- Public state transitions trigger each effect once; polling and role changes do not trigger repeated sounds. Cue selection never depends on which secret role a player has. Playback stops when inactive, hidden or disposed. Initialization/disposal failures are caught and bounded so gameplay continues without an audio device.

Validation: 28 focused Flutter tests passed across game logic, local pass-and-play, legacy practice compatibility, room recovery, fake native audio routing, valid WAV headers, haptics, disabled settings, deduplication, background privacy, rendering and shell navigation. Targeted Flutter analysis reported no issues. Native audible playback/latency and physical haptic strength have not been tested on a real Android/iOS device. No APK was built.

Recovery and test logs: `C:\Users\Abood\AppData\Local\StudyBirds\wink-polish-20261023`.

The app source and assets are mirrored narrowly to fsfs and the platform repository's app folder after matching their pre-edit source baselines. No Android signing, application identity, QA gate, production provider configuration or backend game rules changed.
