# Consultation bookings — 23 September 2026

Local implementation; no Render deployment or production database changes were performed.

## Implemented

- Staff with the explicit `consultations` permission publish their own availability. Admins can publish for any active employee with that permission. Employees see only their slots and bookings.
- Student selects a consultant, mode (online/phone/office), date and available slot. Each appointment lasts 30 minutes, starts on a UTC half-hour boundary and can be published up to 90 days ahead. Interfaces display device-local time and identify the timezone.
- Unique indexes and MongoDB transactions prevent double booking of a slot and concurrent appointments for the same student. Confirmation notifications, reservation claims and booking records commit together.
- A student can cancel or reschedule a future booking. Version checks reject stale updates. An unsuccessful reschedule retains the original reservation. The old consultant is notified when a student changes consultants. Authorized staff can cancel their own bookings; admins can cancel any.
- Meeting link and instructions are disclosed to the booked student and authorized staff, not in the public availability list. Cancellation hides the meeting link from the student's booking list; external meeting links already known to a user cannot be revoked by this API.
- Student and staff web pages: `/student/consultations`, `/admin/consultations`; sidebar permission controls and employee permissions editor use the new permission.
- Flutter's active consultation entry now uses real bookings, shows errors without claiming success, and includes confirmed bookings in its calendar. Tapping an in-app student consultation notification opens the appointments screen.
- An optional scheduler creates internal reminders for bookings within the next hour, with a transactional marker to prevent duplicate sends across workers. Cancellation and rescheduling invalidate the old reminder target. Already-created notification history remains visible.
- Flutter now includes staff/admin availability and booking management, matching the web permissions.
- Staff can publish 1–12 weekly appointments in device-local time, with a preview and confirmation before batch creation. Every date must fit the existing 90-day horizon. The batch endpoint commits all slots together or none if any conflict, including concurrent submissions. These are independently manageable dated slots, not an indefinite recurring rule or a series-editing system. All appointments still last 30 minutes.
- After the 30-minute appointment ends, its consultant or an admin can record completion or non-attendance, a required summary, and optional next steps (up to 2000 characters each). The UI explicitly confirms that notes are shared with the student. Cancelled/future bookings cannot receive an outcome. Version checks prevent overwriting concurrent edits; a dated author-attributed history preserves every revision. The student's notification and the result commit together. The result is visible in both Flutter and the website.

## Deployment dependencies

1. Deploy the backend and web changes together with the updated Flutter app. New collections are `consultationslots` and `consultationbookings`.
2. MongoDB must support transactions (replica set or supported sharded cluster). Tests use a disposable local one-node replica set. A standalone production server will return 503 for booking operations; do not enable this feature until configured.
3. Allow Mongoose to create the declared unique indexes before serving reservations. Routes await model initialization. If production disables automatic indexing, provision the indexes from `server/src/models/Consultation.js` through the normal database migration process before releasing the feature.
4. Grant the `consultations` permission to active consultant employee accounts through existing employee administration, then publish future availability with real meeting links/contact details. No permissions or slots are seeded automatically.
5. Set `CONSULTATION_REMINDERS_ENABLED=true` only when ready to run internal reminders; default is disabled. Scheduler checks every 60 seconds. This does not deliver Push, SMS or email.

## Tests and limits

`server/tests/consultationBooking.test.js` covers auth, staff isolation, invalid/past/off-grid slots, duplicate availability, simultaneous booking conflict, same-student time conflicts and rollback, stale edits, cancellation, failed and successful rescheduling, consultant changes, inactive consultants, meeting-link visibility and reminder deduplication. Run alongside existing server tests using the repository's isolated MongoDB test tooling.

It also covers result authorization, end-time restrictions, validation, stale-result rejection, revision history and student isolation, plus invalid/repeated batch dates, batch rollback and simultaneous batch conflicts. Flutter outcome/recurrence tests exercise confirmation, API payloads, conflict recovery and a 12-date preview on a 360px phone. Latest local verification: 87 Flutter tests and 41 server tests passed; web build passed.

Flutter tests in `test/consultation_booking_test.dart` cover confirmation before writes, real booking endpoint, failed reschedule preserving the original, cancellation, unavailable API and calendar inclusion. No test sends production requests or schedules actual consultations.

PRD 27 and 99 remain **partial**: no Google/Apple calendar synchronization, automatic meeting-provider creation/revocation, Push/SMS/email reminders, indefinite recurring availability, series-wide editing or variable appointment lengths. The user has not selected an external calendar/meeting provider. Student Flutter strings are Arabic; web labels support Arabic/English. Paid consultations and service orders are separate remaining work. Booking history is unpaginated up to 200 rows; available/staff slots up to 500 rows. This update is not deployed by running the source-sync tool.
