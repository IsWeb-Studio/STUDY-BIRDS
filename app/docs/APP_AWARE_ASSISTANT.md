# App-aware Study Birds assistant — 2026-10-22

This extends the earlier `ASSISTANT_SCOPE.md` implementation. All changes are
local; no hosted service, production database or APK was changed.

## Implemented knowledge and measured coverage

The versioned, server-only catalog is
`server/src/knowledge/assistantKnowledge.json`, version `2026.10.22.2`.
It contains 62 reviewed topics, including 48 student-accessible topics and
14 restricted-role topics. Records contain bilingual descriptions, location,
usage steps, role restrictions, availability, prerequisites, backend references
and actual source references. Conditional features are described as conditional;
the absent standalone theme switch is explicitly unavailable. English selection
is described as requiring an `ENABLE_EN` build, not enabled by chat.

The structural inventory scanned 641 source files across Flutter, backend
routes/models/controllers/helpers and web source. It detected 167 public screen
declarations in 82 files. Topic references reach files containing 166 of those
declarations. The remaining declaration is the access-denied guard, explicitly
listed in the inventory. File association is a coverage proxy, not proof that
every sub-screen or button was functionally tested.

See `ASSISTANT_FEATURE_INVENTORY.md` for human-readable workflows and
`ASSISTANT_FEATURE_INVENTORY.json` for the complete source/declaration inventory.
No private records, environment values or source-code bodies are included.

## Runtime behavior

- Approved answers and normalized Arabic/English alias tokens are indexed once
  in memory. Common navigation questions require no external provider call.
- Arabic normalization covers diacritics, alef variants, common suffixes and
  reviewed colloquial/spelling aliases. Unknown wording can still need one
  clarification or a support referral; this is not unrestricted semantic search.
- Ambiguous matches reuse the existing provider as a strict approved-record
  selector. Free-form user messages, old conversations, identity documents and
  private account records are not sent to it. The server never renders provider
  prose or invented routes. Reviewed bilingual steps supply the explanation.
- Context accepts only known screens, language, bounded package-version syntax,
  a knowledge version and a known advisory build flag. Roles always come from
  authenticated backend identity; client flags grant no authority.
- Documents, applications and settings have explicit screen-help actions.
  Main tabs supply their origin. Documents/application help uses reviewed
  screen-specific steps rather than generic instructions to reopen that screen.
- Personal application statuses use the caller-owned, status-only projection.
  Ticket, invoice and service questions cannot accidentally trigger application
  status lookup. Other private-data types retain navigation/referral help.
- Existing authentication, ownership, rate limits, quota and provider timeout
  remain in force. Common help works without provider credentials. Provider
  failures fail safely; failed generations release the per-thread lock.

## Navigation and interface

There are 23 logical shortcut IDs mapped to existing Flutter constructors in
`lib/screens/ai/assistant_navigation.dart`. Each action requires a student role,
matching knowledge version and valid session. Unknown URLs, administrative
routes, deletion and submission commands are rejected. Labels are local,
bilingual and specific; minimum button height is 48 logical pixels. Navigating
only opens a screen. Sensitive actions retain their own confirmation and server
authorization.

Both existing assistant UIs preserve chat/history behavior, scope notices,
theme-aware bubbles, suggested questions and logout/account-switch privacy.
The main UI has an explicit retry control. Phone Arabic RTL, English LTR and
dark tablet layouts are covered by focused tests.

The website has a separate local helper, not a provider-backed personal-data
assistant. It now rejects injection/mixed/out-of-scope requests before keyword
help and requires an authenticated administrative role before showing admin
guidance based on a URL. Its existing reviewed route shortcuts remain local;
the mobile-only shortcut catalog is not executed by the website.

## Source freshness / build-time verification

Run this command before release or in CI with both reviewed checkouts present:

```powershell
node D:\work\studybirds_session_release\server\scripts\assistant-knowledge-tools.cjs --mobile-root D:\work\studybirds_app\study_birds_app-main --website-root D:\work\studybirds_session_release\client
```

The default operation only reads source. It exits nonzero on changed, added or
removed source, changed catalog content, mismatched Flutter knowledge version
or missing shortcut constructors. It reports affected topics through relative
import dependencies, including changes in shared widgets/controllers. It never
publishes or silently updates knowledge. No source scan runs per chat request.

After reviewing affected help, explicitly update the catalog/version and the
Flutter version constant, review the diff, and only then run the same command
with `--record-reviewed-snapshot`. This authoring flag must never be placed in
CI. A missing or hash-mismatched catalog snapshot disables help at startup.
Client/server knowledge-version mismatch suppresses instructions and shortcuts.
CI wiring still depends on supplying both repositories; no remote workflow was
changed or deployed by this task.

## Actual validation

- Backend: 17 tests passed, including retrieval for every one of the 62 topics,
  bilingual/colloquial inputs, disabled features, source-change detection,
  transitive dependencies, version mismatch, unauthorized context, private-data
  ownership, strict output validation, provider failures/simulated timeout,
  concurrent same-thread requests, rate limits and quota.
- Flutter: 472 tests passed in the full suite; nine focused tests were rerun
  after final assistant refinements. Tests cover actual destination construction,
  rejected actions, documents-to-help navigation, both assistant UIs, retry,
  Arabic phone, dark tablet and logout with an in-flight response.
- Website: 103 tests passed; TypeScript no-emit checking passed.
- Flutter analysis: no issues found.
- Source/catalog verification passed with no outstanding changes.

The backend tests use isolated MongoDB and mocked providers. Flutter contract
tests can replay JSON captured from the isolated backend through ApiClient;
they are not a live-device/live-provider end-to-end test. No Android APK build,
installation, production request, dependency upgrade or QA-gate relaxation was
performed.

## Remaining release boundaries

These are source-verified local capabilities, not proof of hosted availability.
Actual provider behavior, external feature/provider configuration and physical
device workflows still require authorized release/QA work. Knowledge remains a
reviewed guidance system, not an unrestricted chatbot: missing university fees,
requirements or deadlines are referred to the current catalog/support.

Existing Git work, protected artifacts, QA services and recovery checkpoints
are preserved. Pre-edit copies, hashes, logs and continuation evidence are in
`C:\Users\Abood\AppData\Local\StudyBirds\assistant-aware-20261022`.
