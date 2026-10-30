# Student team CRM bridge — 2026-10-23

## Verified cause

The owner-selected platform checkout is `D:\work\studybirds_web` (main, f42dc7a at inspection). It did not expose `/students/support-team` or store `StudentSupportTeam`, while the separate session-release worktree contained the earlier implementation. The reviewed CRM main checkout had no student support-team editor or bridge. CRM consultant/application assignment and employee department are separate fields; changing them does not write a student's support team.

## Local implementation

- Website main: additive team model/controller and student read endpoint; CRM read/write endpoints with student-section reads and website-admin-only writes. Only active administrators or active employees with existing support permission may be selected. No permission is granted automatically.
- CRM: explicit team editor inside student records. The server resolves the student in the authenticated company and uses its existing, explicit website account ID. No email/name guessing or automatic account linking. Unlinked students, invalid/duplicate IDs, disabled website writes, insufficient permissions and upstream failures do not claim success. Assignment goes directly to the website API, not to an unrelated CRM-only field.
- Website student support page: assigned team display, refresh every 15 seconds while visible and on focus. Failed reads clear stale names.
- App: uncached team fetches and periodic refresh of the open, foreground My Team screen; timer is disposed when leaving.
- Website messaging: scoped assigned-team contact lookup and direct staff-contact membership checks, including revoked assignments. General peer/community history is preserved.
- Session-release backend: same additive CRM route aliases, reusing its existing team controller/schema.

CRM working checkout: `C:\Users\Abood\AppData\Local\StudyBirds\crm-team-fix-20261023` (fresh sparse checkout of the owner-specified repository). Existing project directories were not moved.

## Validation

- Real website API against synthetic local MongoDB: assignment, validation, unauthorized writes, student privacy, scoped contacts, replacement/revocation and inactive-member filtering passed.
- Session-release student-team, support-team messaging and CRM regression tests passed together: 4 Node tests, including the website-main integration test.
- Website-main team component: 2 tests passed (refresh/replacement/removal and failure/recovery).
- CRM bridge: 1 Node test passed with multiple assertions for company isolation, missing link, exact upstream route/payload, malformed IDs, write gate, role gate and upstream denial propagation.
- CRM changed JSX parsed successfully using installed esbuild; server entry syntax passed `node --check`.
- Website-main TypeScript `tsc --noEmit --project tsconfig.app.json` passed.
- Flutter team refresh and urgent-team routing: 3 widget tests passed.
- Broader CRM accountBridge test could not start in the fresh checkout because `immer` is not installed there. No dependencies were installed and no production services were accessed. This is not a full CRM startup or browser integration test.

## Release and usage boundaries

Initial implementation was local only. Superseded by the follow-up correction below after the owner's screenshot identified the actual Save Follow-up control. Existing CRM assignments are not bulk-converted and no employee permissions are automatically granted.

After review and deployment of both server changes and CRM UI, an authorized manager opens the linked student's record, selects existing support-authorized website accounts under **الموظفون المسؤولون عن الطالب**, and presses **حفظ فريق الطالب**. The website integration must already have writes enabled and website-admin authority. If either is missing, the operation remains denied; do not bypass the guard. The student sees the team in app My Team and website support. Live hosted behavior remains unverified until these local changes are released.

Recovery/evidence: `C:\Users\Abood\AppData\Local\StudyBirds\team-sync-20261023`. Restore only reviewed task-specific changes if rollback is needed; preserve other dirty/untracked work and Git worktree relationships.

## Follow-up correction: actual Save Follow-up path

The screenshot uses `StudentWorkspace.jsx` → `PATCH /api/students/:id/crm`, which previously saved only CRM-local `consultantId`. The earlier separate team editor did not fix this flow.

The existing Save Follow-up handler now validates the company-scoped student/employee, resolves explicit existing website account mappings, calls `PUT /crm/students/:id/advisor`, and only then saves CRM notes/assignment. Failed website writes or missing links return an error without local success. Retrying is idempotent; saving the same advisor again re-sends synchronization, covering assignments saved before this fix. A network timeout or subsequent local storage failure can leave the website updated before local acknowledgement; an explicit retry converges safely. This is not a distributed database transaction.

The website stores the CRM advisor separately from manually selected members. Student team reads include both, filtered to active support-authorized accounts; replacing/removing the CRM advisor preserves manually assigned members. Messaging and session-release ticket access include the CRM advisor. No migration or bulk rewrite was run.

Validation: 3 CRM bridge/follow-up tests passed; 3 local backend tests passed; both isolated release checkouts passed their actual API integration test (2 tests). Existing Flutter/team tests remain as recorded above. Changed CRM JSX/server syntax passed. Broader CRM suites require dependencies absent from the fresh checkout (immer/multer); full live student login/assignment was not performed.

Owner-authorized main-branch pushes, performed from isolated checkouts to preserve all existing local indexes/worktrees:

- IsWeb-Studio/STUDY-BIRDS: `4461252d9cbd250efdcda2e82ba1b9ca16e41ac1`
- aboodsiaj2/studybirds_web: `2708ac0`
- aboodsiaj2/fsfs: `290e31e`
- IsWeb-Studio/CRM-Study-birds: `96cc6694c39167868b1aef7077a354a611269aa1`

Render inspection confirmed the CRM service's old IslamOsman1 URL resolves to the same repository/commit. Specific reviewed commits were submitted for deployment without changing service configuration. Final deployment evidence is recorded separately in `C:\Users\Abood\AppData\Local\StudyBirds\advisor-followup-20261023`.

Once backend and CRM deployments are live, reload the CRM page and press **حفظ المتابعة** once for the existing selection; then refresh **فريقي**. No new APK is required for the existing team's initial API load to show the server-side assignment. The fsfs change adds automatic foreground refresh and requires a later app update to take effect.

## Actual account-link diagnosis after owner retry

Read-only, projected checks of the configured CRM database found three same-name student records in the configured company. Two point to website accounts returning 404; one points to a valid website account whose assigned team remains empty. The selected advisor on that valid CRM record has a local linked CRM user, but neither the employee nor user has a website account mapping. The website has zero support-authorized or employee accounts matching that CRM user's exact email. No records were changed, merged, linked or deleted during diagnosis. Do not infer identity from the shared display name or bulk-repair these records.

This is an unresolved owner account-provisioning prerequisite. The advisor needs a website employee account with support access and an explicit CRM link. Account provisioning/password input must occur in the owner's normal local UI; do not invent a password or silently grant permissions.

Commit `7a2e6e5ede5b9fd00a21beffc8163d738e4c117b` adds explicit account-link metadata to the follow-up response, labels unlinked consultants, displays errors above the save form and displays pending/success feedback. Four focused server tests and two actual component tests passed. Component tests use the installed React 18/jsdom toolchain, rather than asserting a full deployed React 19/browser run. A Render deployment was submitted (`dep-dbd9dmvb9u1s738sqnjg`); its final status is not implied by this report. Vercel frontend delivery remains independently unverified because the connection could not be established from this environment.

Sanitized evidence: `C:\Users\Abood\AppData\Local\StudyBirds\advisor-followup-20261023\ACTUAL_LINK_BLOCKER.json`. No private database extracts or secrets were persisted in that receipt.
