# Application follow-up reminders

The API server has an optional in-process scheduler. It creates internal notifications only; it does not send email, SMS or Push, change admissions decisions, or automatically assign employees.

## Activation

After deploying the new server and client, set `FOLLOW_UP_REMINDERS_ENABLED=true` on the server service and restart it. `FOLLOW_UP_REMINDERS_INTERVAL_MS` defaults to 300000 (5 minutes), minimum 60000. The example defaults to disabled. No secret is required. This change has not enabled or deployed the scheduler on Render.

The scheduler scans once after startup database connection, then at the interval. It skips disconnected periods and overlapping scans in the same process. An always-running service is required for timely delivery; a sleeping or stopped Render service cannot run timers. Overdue work is caught on its next successful scan. Invalid configuration is logged without stopping the HTTP service.

## Delivery and scope

An active admin or employee with applications permission receives one notification for an assigned application's deadline once due. Rejected/completed applications, unassigned applications, future deadlines, disabled accounts and ineligible staff are skipped. Recipient, application and exact deadline form a deterministic notification ID, so concurrent instances and retries do not duplicate it. Marking it read does not reset it or complete the task. Choosing a different deadline or advisor creates a separate reminder when due; returning to an identical prior assignment/deadline reuses its existing reminder.

The staff reminders page (website applications page and Flutter employee dashboard bell) lists current matching overdue assignments only. Historical notifications remain stored. Reassignment, deadline changes or closure remove them from this current list. A state change can race with creation after the final recheck; the current list filters stale entries, but historical notifications may still contain such an entry. There is no atomic cross-collection transaction.

Staff can open the specific application and acknowledge reading. Follow-up completion is handled by updating/clearing the deadline from the website assignment form. Automated recurrence, escalation, student reminders, and stage-specific SLAs are not implemented. No migration or historical notifications were generated in production.

## Verification

Temporary-Mongo tests exercise concurrent scans, idempotency after acknowledgement, future/new deadlines, disabled recipients, closure, unassignment and per-user read authorization. Scheduler startup is opt-in. Flutter tests verify authenticated fetch and acknowledgement; local builds do not prove production configuration or delivery timing.
