# Assigned support-team chat — 2026-10-22

Implemented locally. No production deployment or APK build.

The Emergency Help internal-chat button now opens `ConversationThreadScreen`
with `supportTeamOnly: true`. That list requests
`GET /mobile-workspace/contacts?supportTeam=true`, which returns only active,
support-authorized members of the authenticated student's current team. An
unassigned student sees a clear empty state and a support-ticket referral.
There is no fallback to all accounts or all administrators.

Server authorization is enforced on student/staff pairs in both directions,
including direct-contact lookups, history, sends, read receipts, images and
other existing endpoints using `requireContact`. Guessing a staff ID cannot
bypass team membership. Removing a member, disabling them or revoking their
support permission removes access without deleting historical messages.
Administrators must also belong to the student's team for direct chat.

General student-community conversations and existing linked parent/university
contact rules remain separate. Assigned employees can now find and reply to
their students. Team assignment is still managed in the existing web student
file; this fix does not create or assign teams automatically. Emergency phone,
WhatsApp and ticket behavior were not edited.

The assistant knowledge entry for messaging was updated to describe this flow;
its version is now `2026.10.22.3`, with matching Flutter bindings and a reviewed
source snapshot. The previous orange navigation selection change was included
in source-freshness review; its navigation instructions did not change.

Validation uses synthetic users and isolated MongoDB. Tests cover assigned and
unassigned employees/admins, direct-ID attempts, reverse sends, team changes,
disabled/revoked members, image/read/history access, ordinary community chat,
chat controls and the Emergency Help entry/empty state. Exact results and
pre-edit recovery copies are under
`C:\Users\Abood\AppData\Local\StudyBirds\support-team-chat-20261022`.

Hosted users need the authorized backend rollout and refreshed mobile build
before this change is active. No live account assignments were inspected or
modified, and no live QA service was stopped or restarted.
