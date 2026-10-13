# Post-admission journey and assignment review — 23 September 2026

## Implemented behavior

Each accepted, active application has six independent follow-up stages: visa, travel, housing, arrival, university registration, and residence/ongoing support. Each stage records its status, student-facing note, optional deadline, verification reference, and update time. Completion requires a non-empty reference. Staff can record a stage as not required with an explanatory note.

Staff with the existing `applications` permission edit stages from the website's application follow-up panel after confirmation. Changes use application version checks, append an audit event with the editor identity, and preserve the admission status. Students can only read their own stages. Closed applications retain existing evidence and reject updates.

The overview API includes the stages in the existing journey response. Action-required and overdue stages contribute to the next action, while overdue invoices and urgent missing-document requests retain priority. Flutter's existing journey screen renders the statuses, deadlines and references. The website student application page includes the same read-only view; its dashboard action opens the matching application's panel.

## Assignment review fixes

- Manual assignment changes clear `autoAssignmentEligible`, so an earlier requeue action cannot override a later manual cancellation.
- Requeue eligibility uses the same admissions-status policy as the worker, with a status/version compare-and-swap during the write.
- The website uses server-provided `canRequeue` and `isQueuedForAutomaticAssignment`. Closed, draft and final-admission cases cannot be shown as awaiting a worker that does not process them.

## Validation

- 70 Flutter tests passed using the SDK recorded in the local package configuration (`C:/Users/Abood/flutter`).
- 40 server tests passed on isolated MongoDB instances, including the new post-admission integration tests and a regression test that failed before the manual-cancellation fix.
- Website TypeScript and production build passed. Source synchronization test passed.
- This is local validation. No production data was used in the server tests and no deployment is included.

## Apply the reviewed source bundle

```powershell
node integration/sync-assignment-source.cjs --target D:\work\studybirds_web\STUDY-BIRDS-main --bundle journey
```

Add `--apply` to copy only the reviewed files. The manifest checks existing file hashes and refuses to overwrite subsequent edits. This bundle builds on the current website requeue implementation, preserving its endpoint and audit event.

## Remaining PRD scope

These are staff-maintained follow-up stages. Full visa processing, available housing inventory and reservations, flight booking, pickup driver tracking, consultation slots, and independent priced service orders still need their own workflows and APIs. References are staff-entered evidence identifiers, not verification against external providers. Configurable country/university rules, specialist permissions and owners per stage, automatic escalation, Push, and real-time updates remain open. Updates appear when the student loads or refreshes the view. The fixed stage list is an initial implementation, not completion of the configurable journey engine.
