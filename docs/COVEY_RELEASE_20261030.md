# COVEY release ? 2026-10-30

Target: IslamOsman1/STUDY-BIRDS main. Integrates the local web/API changes and Flutter app into the deployed main branch; Flutter sources live under app/.

- COVEY branding, native launch artwork and launcher icons.
- Student dashboard, stories, grouped navigation and community UI.
- Community text/photo publishing, optional title, administrative-author filter and reactions.
- Keep AI and new-post actions at the bottom of the community page; remove microphone recording controls.
- Account profile, notification routes, support team access and push announcement updates.
- Durable account/media cleanup, blocking and retained existing CRM, identity, AI provider and maintenance behavior.
- Fix assistant completion lock release before responding, so immediate follow-up messages do not incorrectly return 409.
- Pin reviewed knowledge artifact to LF line endings to preserve its integrity hash after Linux deployment.

Validation on the integrated source:
- Flutter static analysis: no issues.
- Flutter tests: 592 passed, 1 skipped.
- Website tests: 81 passed; production build passed.
- API suite: 298 passed, 5 skipped. Story/voice and assistant suites rerun for subsequent integration changes; final assistant lock regression passed.

No Render deployment was triggered manually. The owner manages Render updates. Store publication, real device testing and production provider credentials remain external deployment checks.
