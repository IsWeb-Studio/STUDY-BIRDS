# Automatic admissions assignment

This local source bundle adds optional assignment to the existing application workflow. It does not deploy or enable production behavior.

## Behavior

- Only unassigned, submitted/under-review/additional-document cases with no assignment history are candidates. Drafts, final admissions and closed cases are excluded.
- Only active employees with the `applications` permission and an `admission`, `admission_manager` or `educational_consultant` role are eligible. Administrators are not automatically treated as advisors.
- Select the lowest active application count; break ties by employee ID. Count all open assigned cases, including later admissions stages, toward the load limit.
- Set the follow-up date, increment the application version and append an audit event with `source: automatic`. Preserve application status. Existing website assignment controls and mobile journey views read the same fields.
- Manual assignments are protected by compare-and-swap. Clearing a manual assignment leaves history, so the scheduler will not immediately reassign it. Such cases require another manual assignment.
- A renewable MongoDB lease coordinates scheduler instances. Interrupted workers expire after 60 seconds. Repeated scans do not duplicate assignments.

## Configuration after deployment

All defaults leave automatic assignment disabled. No `.env` file is included or changed.

| Variable | Default |
| --- | --- |
| `AUTO_ASSIGNMENT_ENABLED` | `false` |
| `AUTO_ASSIGNMENT_INTERVAL_MS` | `300000` (minimum `60000`) |
| `AUTO_ASSIGNMENT_MAX_OPEN` | `20` |
| `AUTO_ASSIGNMENT_DUE_HOURS` | `48` |
| `AUTO_ASSIGNMENT_BATCH_SIZE` | `100` |

The existing reminder worker is separate and still requires `FOLLOW_UP_REMINDERS_ENABLED=true` to issue overdue notifications. Stopping the scheduler prevents future scans; a scan already in flight can finish. Disabling the feature does not undo existing assignments.

## Synchronization

From the Flutter repository, inspect the reviewed changes with:

```powershell
node integration/sync-assignment-source.cjs --target D:\work\studybirds_web\STUDY-BIRDS-main
```

Add `--apply` to copy them locally. The script checks every source and destination hash first and refuses to overwrite changed destination files. It is safe to rerun after a successful copy. It never publishes or accesses a production database.

## Validation

`server/tests/automaticApplicationAssignment.test.js` uses an isolated MongoDB memory server and covers load balancing, eligibility, audit/deadlines, idempotence, concurrent workers, capacity, expired leases, batch limits, manual conflicts, lease loss and disabled/invalid configuration. Also run the existing `applicationAssignment.test.js` to check permissions, student visibility and reminders.

Set `STUDY_BIRDS_TEST_TOOLS` to the directory containing `node_modules/mongodb-memory-server-core`. Test dependencies are not production dependencies.

## Remaining scope

This is admissions assignment only, not the complete PRD journey engine. Country/specialty routing, working hours, escalation and multi-role teams remain open. The capacity limit governs automatic selections against current database counts; concurrent manual assignments, changes to staff eligibility, or a worker paused beyond its lease between its final check and write are not serialized in a cross-collection transaction. Application version checks still protect against overwriting manual changes to that application. Strict capacity and staff-state invariants require a transactional reservation design.
