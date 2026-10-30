# Study Birds application support assistant

Implemented locally on 2026-10-22. No deployment or APK build was performed.

## Server boundary

`server/src/utils/assistantScope.js` is the reviewed bilingual help collection.
Each record references its real Flutter screen source. It covers applications,
documents, the university/program catalog, accounts, notifications, community
and support. Maintain these records when the corresponding screens change.

`server/src/routes/assistantRoutes.js` still authenticates every endpoint and
restricts conversation reads/writes to the caller. It classifies requests before
provider invocation. General questions, recognized injection attempts and
cross-user requests receive a scoped refusal. Ambiguous requests receive a
short clarification; screen context accepts only known screen identifiers.
Client context grants no authority and never controls database queries.

For app help, the external provider receives only approved topic IDs and a
strict selection instruction. It receives no free-form user text, conversation
history, application records, identity documents, editorial knowledge-base
bodies or arbitrary client screen strings. Its output must parse as exactly
one permitted help ID. The server returns the reviewed Arabic/English answer,
never provider prose, arbitrary links or model-generated routes. Invalid output
produces a support referral. No web search or model actions are available.

Personal application-status questions are answered directly from an
authenticated `student` query with a status-only projection, latest ten records,
and approved status labels. User/application IDs supplied in the body or text
are not query selectors. Personal records do not go to the provider. No
application submission, payment, document mutation or account action is offered.

Existing limits remain: 2,000-character messages, five requests/minute per
authenticated account, configured daily quota capped at 100, and the provider's
30-second timeout/output limits. Minute-limit errors now use a JSON response.
Provider failures remain safe errors and release the conversation lock.

## Flutter

Both existing assistant implementations use app-support language and scoped
suggestions. The main assistant provides a fixed shortcut to the actual Support
Center screen, localized text/direction, theme-aware surfaces and phone/tablet
layouts. Its launcher supplies the known main-tab origin. No server-supplied
route is executed. Conversations are cleared on logout/account change, and late
responses are ignored. Refreshing a token for the same identified account does
not invalidate the conversation.

## Verification

- 11 backend tests passed against isolated temporary MongoDB and mocked
  providers: scope, Arabic/English, injection, mixed requests, unknown routes,
  stale/unavailable catalog information, private projections, body-ID attacks,
  cross-user threads, authentication, rate limits, quota, provider errors and
  strict output selection.
- 468 full Flutter tests passed before the final text/session refinements.
- Six focused Flutter tests passed after those refinements: both assistant
  implementations, actual isolated API response replay, Arabic RTL phone,
  dark tablet, logout with an in-flight response and main-tab shortcut scope.
- Flutter analysis: no issues found.

The response replay uses the JSON actually returned by the isolated backend
test through Flutter's real ApiClient with a mock HTTP transport. This is
contract/UI integration evidence, not a running-device or live-provider test.

Evidence and verified pre-edit copies are under
`C:\Users\Abood\AppData\Local\StudyBirds\assistant-scope-20261022`.

## Limits and release boundary

Help answers are deliberately curated rather than unrestricted generation.
Specific tuition, deadlines and university requirements are not inferred from
general knowledge or potentially stale articles: students are directed to the
current catalog and Support Center. New help topics require reviewed records.
Stored older conversations are preserved; they are never fed back to the model.

No production database/provider, live QA process, signing configuration,
Android QA gate, Git history, index or worktree registration was changed.
The backend changes need a separately authorized rollout before they affect
hosted users. A refreshed app build is needed for the new Flutter UI. Live
provider behavior and physical-device rendering have not been exercised.
