# Concise app-aware assistant — 2026-10-23

Implemented in both existing Flutter assistant screens, using the existing 62 reviewed topics and 23 safe destinations.

## Actual behavior
- The server derives concise text from the same reviewed record, preserving relevant cautions; additional useful instructions are returned as optional details. Generic disclaimers are not repeated in every short answer.
- The local Explain More / اشرح أكثر button replaces the text inside the same bubble, supports collapsing and makes zero network requests. Empty, duplicate or incompatible-version details never offer expansion.
- Details and server-selected topic IDs persist with account-owned threads. Old messages remain compatible. Follow-ups use only the previous server-owned topic, with exact intent, role and version checks. Client-supplied topic IDs cannot change this selection.
- Current-screen help does not offer a redundant shortcut back to that same screen. Unavailable features still have no invented action.
- Authenticated application status answers show three latest entries initially; the already-authorized remaining entries expand locally. Private records never go to the provider.
- Added reviewed Arabic intent aliases for documents, passport, application, profile, streak and notifications. Provider use remains limited to ambiguous approved-topic selection, with existing rate, quota, timeout and ownership checks.
- Robot avatar is bundled at assets/images/assistant/robot.png and used in the main shortcut, dashboard quick action and both assistant chat surfaces. No launcher or navigation identity was changed.

## Before / after examples
Before: document help presented the full guide, including application-specific instructions and repeated general caveats.
After (Arabic): «مستنداتي أو الطلب ← المستندات. افتح مستنداتك لإدارة الملفات. لا ترسل صور الهوية أو رموز التحقق في هذه المحادثة.» Expand to see the complete verified file/application instructions.
After (English, opened from Documents): “Documents. Tap Upload document at the top of My Documents.” Expand to see document type, camera/file choice and upload-result instructions.
Follow-up: «طيب وين الزر؟» stays on the previous reviewed topic; «مش ظاهر عندي» cannot switch to restricted staff help through a forged topic ID.

## Validation
- Flutter: 11 tests passed, including both chat screens, zero additional requests on expansion/collapse, RTL Arabic at 320px in dark theme, hidden stale/empty/duplicate details, logout/in-flight privacy and safe navigation.
- Flutter analyze: no issues across modified UI and tests.
- Backend: 20 tests passed across disclosure, knowledge, API, scope, grounding, providers and release regressions. Includes persisted details, cross-account denial, follow-up selection, status disclosure, provider failure, quota and concurrent request locking. Final pure knowledge/disclosure recheck: 8 passed.
- Website assistant scope regression: 3 passed; website source unchanged.
- Reviewed source ledger: 648 source files, 168 screen declarations; knowledge version 2026.10.23.2.
- No APK build, commit, push or deployment. Real-device appearance and installation remain untested. Local mobile/backend changes require coordinated release; older history has no fabricated expansion details.

## Image provenance
Built-in image generation; transparent PNG inspected and copied into the repository. Original generation remains preserved.
Prompt: Use case: stylized-concept. Asset: original Study Birds in-app assistant avatar, readable at 32 pixels. One friendly premium 3D rounded robot head, white pearl shell, navy glass face, expressive cyan eyes and a simple warm smile, small orange ear accents. Front-facing centered symmetrical compact bust, fills square with modest padding. Soft studio lighting, clean silhouette, transparent background. No text, letters, watermark, extra objects or speech bubbles.

## Recovery
Verified pre-edit file copies and hashes are in C:/Users/Abood/AppData/Local/StudyBirds/assistant-concise-20261023. Preserve unrelated local work; restore only the reviewed files individually if rollback is needed. New optional message fields require no destructive database migration.
