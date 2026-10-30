# Assistant scope fix — 2026-10-23

## Result

The assistant paths in the Flutter app now require a matching server contract (`studybirds-only-v1`, `verified-help-v1`, knowledge version `2026.10.23.3`) before enabling chat. Every response is checked against the same contract. If the installed API still returns the old general-answer contract, both assistant entry points remain disabled and do not send the user's message. Responses render concise verified help first; an optional “Explain More / اشرح أكثر” expands details already returned by the server in the same message. The details are plain text, with unsafe Markdown links removed.

The server changes classify questions against the reviewed Study Birds scope. Out-of-scope prompts such as “مين حرر الجزائر؟” receive a short bilingual Study Birds-only refusal. For an in-scope query, the server retrieves the approved bilingual knowledge record; where needed, the optional provider only selects among approved topic IDs, not arbitrary answer prose. Older replies without a knowledge version are replaced with a stale-message notice. Account ownership checks remain on conversation reads.

## Files and checks

The implementation is in the Flutter assistant screens and their contract/answer/navigation widgets, and in the server assistant route, scope/knowledge helpers, and reviewed knowledge catalog. The source ledger was refreshed after reviewing the changed assistant source files: 649 source files, 168 screen declarations, 62 topics. Ledger verification passes with no unreviewed changes.

Passed locally:

- Flutter `flutter analyze`: no issues.
- Flutter assistant tests: 12 passed, 0 failed.
- Node assistant scope/knowledge/disclosure tests: 13 passed, 0 failed.

The authenticated HTTP integration suite was not rerun in this environment: `mongodb-memory-server-core` is absent from the installed offline test tools. No dependencies were downloaded. No APK was built, no device was accessed, and no service was restarted or deployed.

## Running-service boundary

The Flutter app's default API is `https://study-birds1.onrender.com/api`. The latest public health response observed during this work reported build commit `4461252d9cbd250efdcda2e82ba1b9ca16e41ac1`; the local server checkout is at `e9060536e8dc7a70150da9c42d6dfac901713553` with uncommitted work. These are different revisions. The authenticated assistant contract could not be read without a user session, and the local code has not been deployed. Therefore this work does **not** establish that the running Render server or an already-installed tablet APK contains the fix.

To exercise it on the tablet, the server and app must be released as a matched pair: first deploy/review the server contract, then build a new test APK against that API, then test Arabic and English in-scope help, “مين حرر الجزائر؟”, local detail expansion, and an old-contract server response. Until then, the local source/tests are verified, but the original tablet behavior remains unverified.
