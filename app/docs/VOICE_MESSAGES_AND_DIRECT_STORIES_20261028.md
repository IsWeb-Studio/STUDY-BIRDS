# Voice messages and direct story publishing

> Update 2026-10-29: Voice recording and Bird AI dictation have been removed from all mobile composers at the owner's request. Recording and speech-recognition dependencies and microphone/speech permissions were removed. Existing audio attachments remain playable. The voice-capture behavior below documents the previous implementation; direct story publishing is unchanged. This removal requires a new mobile build, with no server deployment.

## Behavior

- The shared human conversation composer and support ticket thread offer a microphone. Recording starts only after an explicit action and OS permission. The user can stop, listen, cancel or send. Limit: three minutes and 5 MB, AAC in M4A.
- Failed sends retain the recording and operation ID for a safe retry. Typed drafts remain intact. Leaving the app cancels an active recording; playback pauses when leaving the screen/app or changing accounts. Temporary files are removed when the recording/player is disposed.
- Both Bird AI composers offer device speech recognition. A disclosure precedes recognition. Recognized words enter the editable draft only after “Use text”; nothing is sent automatically. Device language/service availability and Apple/Google processing depend on OS settings.
- Support ticket recordings can be loaded and played in the student, partner and both admin web views through an authenticated request.
- New-story taps on existing non-admin publishing accounts open the system photo picker and immediately upload/publish the selected photo. Cancelling selection publishes nothing. Retry reuses the published operation and uploaded URL. The admin composer remains unchanged. Existing agent exclusion remains unchanged.
- The supplied server copy previously allowed only student stories. Parent, university and employee story uploads/read access now match their existing mobile entry points. Story posting rewards remain student-only.

## Backend and deployment

The server and web client in `D:\work\studybirds_web` must be updated on Render, then a new mobile build must be installed/distributed. No deployment was performed.

New endpoints: `POST /api/mobile-workspace/messages/audio`, `GET /api/mobile-workspace/messages/:id/audio`, `POST /api/voice/tickets/:id/replies`, and `GET /api/voice/tickets/:id/replies/:replyId/audio`.

Cloudinary uses private authenticated video resources for audio, with signed server-side downloads. Existing Cloudinary configuration must permit audio/video uploads. Storage IDs do not appear in API responses. Uploads validate container structure, MIME, size and provider-reported audio tracks/duration. Participant checks, block rules, hidden/cleared messages, unsend and account deletion apply. Ticket access requires ownership or support-ticket staff permission; closed tickets reject new recordings.

Android requests microphone access on demand and declares speech-service visibility. iOS declares microphone and speech recognition usage and Audio Data in its privacy manifest. These supersede older store preparation notes that removed microphone access. Update Google Play Data safety and App Store privacy answers to include voice messages/audio data; the website privacy copy is updated locally.

## Validation and limits

Android debug APK builds successfully after narrowing the old Kotlin 1.8 override to Sentry. All 21 debug 64-bit native libraries pass the existing ELF 16 KB segment alignment check; this is not release ZIP alignment verification.

The full Flutter suite passed 580 tests. After the final account guard and student publishing case, 13 targeted composer/story/chat tests passed and Dart analysis reports no issues. Backend checks cover authenticated delivery, unauthorized reads, retries, unsend, closed tickets, private storage metadata, account-deletion assets and role-specific upload/publish/feed behavior. Existing chat-control and community-messaging tests also pass. Web production build passes.

Real-device recording, interruptions, Bluetooth/headset routing, Arabic/English OS dictation and iOS build/permission behavior still require device QA. iOS cannot be built on this Windows workstation. No production messages, stories or recordings were sent by these tests.
