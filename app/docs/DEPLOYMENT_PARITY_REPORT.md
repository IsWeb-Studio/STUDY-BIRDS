# Flutter deployment parity — Phase 2

Compared sources on 21 October 2026:

- Selected: `D:\work\studybirds_app\study_birds_app-main` (fsfs), including uncommitted Phase 1 fixes.
- Deployment copy: `D:\work\studybirds_session_release\app` at the existing deployment HEAD.

Neither source was synchronized, pushed or deployed. Comparison copies under private Git metadata were formatted with the same Dart 3.13.4 formatter to distinguish formatting noise from source differences. Originals were untouched by normalization. A second whitespace/const/block heuristic was used only for triage, not as proof of semantic equivalence; significant remaining hunks were inspected directly.

## Correction to the earlier raw-file interpretation

The Phase 1 figures of approximately 150 differing files and 18 absent paths were a **raw source/configuration hash inventory**, not 150 missing features or 18 missing source modules. Current normalized Dart comparison yields the exact per-file appendix below. Many remaining differences are `const`, braces, comments, unused imports or API deprecation cleanup.

Of the 18 absent paths, **17 are generated/local/signing files**: Android generated plugin registration, Gradle wrapper outputs/scripts, keystore and key/local properties; iOS generated xcconfig, export environment, plugin registration and ephemeral Swift/debug integration. They must be generated/configured privately, not synchronized from a developer machine. **Only `test/story_deletion_test.dart` is an additional feature test file.** Some of the generated paths are ignored; absence from a source checkout is expected and not a broken feature.

Android `PassportScanner.kt` and `data_extraction_rules.xml` compare equal after ignoring line endings. Their initial differing hashes do not establish an OCR or backup-policy feature gap. Public trust-bundle formatting differs; do not merge certificates based on text hashes—preserve the intended root set and fingerprint tests. Build manifests and provider identifiers must be reviewed independently from generated signing files.

## Feature-by-feature comparison

### Authentication, email/password setup, session refresh and transport

Normalized `auth_session.dart` differences inspected are constant constructor changes in role routing; Google initialization and auth-screen differences are braces/constant widgets. RootChooser's password/email gate is present in both; its differing hunks are error-state blocks/gallery constants. `ApiClient` and pinned HTTP transport normalize identically, so no different wire/auth-refresh contract was identified between these two app copies. ErrorReporter's FormatException redaction exists in both; the extra comment in fsfs is not a security feature missing from deployment.

Recommendation: keep the current logic. Port only lint/deprecation cleanup if desired, with the existing authentication/session/email tests. Do not replace either transport or auth flow merely because its raw hash differs. No production identity-provider configuration was tested here.

### Story deletion and feed synchronization — REAL DIFFERENCE

Selected `StoriesRepository` has session-scoped pending/hidden deletion state, a change stream, deduplicated concurrent deletes and rollback on request failure. Its feed excludes hidden stories and retains pending items across refresh so failures can restore them. Deployment only awaits the server DELETE; it lacks those optimistic coordination hooks.

Selected `student_stories.dart` listens to repository changes and filters hidden items; deployment does not. Selected viewer removes the confirmed story route immediately, including the exact-route dialog fix; deployment awaits deletion and shows a pending state. This can produce slower visible feedback and stale list behavior in a deployment-built APK. Both call the same DELETE endpoint; this is client coordination/UX, not a new server API.

Port as one reviewed unit: repository + feed + viewer deletion handling + `story_deletion_test.dart` + the immediate-delete regression in `story_viewer_test.dart`. Test failed DELETE rollback, in-flight refresh, repeated taps, account switching and dialog/route ownership. Do not combine it automatically with the old uncommitted deferred server-deletion experiment.

### Story viewport and controls — REAL UI DIFFERENCE, APPROVAL NEEDED

Selected viewer fills the screen with cover-fitted media and repositioned overlays/like controls. Deployment retains the older card layout. This was an earlier implemented design choice, not a defect discovered in Phase 2. Reconciling it changes the deployment APK's appearance and hit targets, so present it separately for approval. Preserve viewport, video lifecycle, gesture, timer and accessibility tests. No wholesale viewer replacement was performed.

### Story loading and viewer lists — SHARED FEATURE, PRIVACY FIX MISSING IN DEPLOYMENT

Both have the segmented loading indicator, owner-only viewer control, paginated viewer page and matching `/stories/:id/viewers` API. The fsfs copy additionally includes the Phase 1 session listener that clears private names/cursors and rejects late responses after logout. Deployment lacks that fix and its new logout regression in `story_viewers_test.dart`.

Recommendation: port only the page privacy patch and regression first. It is independent of fullscreen design. Keep API pagination/error-retry behavior and owner-only authorization tests; do not claim the whole viewer-list feature is absent.

### Navigation, profile photo, passport identity, support teams and streak restores

These recent features exist in both sources. The approved bottom navigation/profile control, passport automatic identity screen and support-team API usage are not missing wholesale. Profile-screen differences inspected are largely const/block cleanup. Backend streak/manual-restore and identity/support behavior stays in the selected API; no alternate contracts were found by comparing the app model/repository sources. Retain current feature regression suites before any release-copy reconciliation.

### Card surfaces and Flutter SDK compatibility

The selected `AppCard` includes Phase 1's Material surface fix for ListTile ink rendering; deployment's ordinary non-onTap cards still omit it. Port this small widget change with the profile-card regression independently of story design. Selected documents/notifications/banner use `TickerMode.valuesOf(...).enabled`; deployment uses deprecated `TickerMode.of`. Other inspected differences include `withValues(alpha: ...)`, dropdown `initialValue` migrations and `whereType<Map<...>>()` instead of equivalent filtering. Group these as SDK maintenance, not missing business modules.

### Tests and release confidence

Selected-only test file: `test/story_deletion_test.dart`. Existing selected tests also add immediate-delete/cover-viewport and logout-private-viewer regressions. Most other differing tests merely add braces/const or remove unused imports. A comment explaining queued secure-storage commits is not a separate changed authentication contract.

Phase 2 validation targets the authoritative app. The deployment copy was semantically compared, not rebuilt and certified as interchangeable. A future parity patch must be applied and validated in its own worktree before release.

## Safest reconciliation order

1. Small privacy and Material-card patches, each with its regression tests.
2. SDK deprecation/lint maintenance, keeping SDK/CI aligned.
3. Optimistic story deletion as the complete repository/feed/viewer/test unit.
4. Fullscreen story design as a separately approved visual change.
5. Validate the deployment app independently, record source/version/commit, then obtain release authorization. Do not copy local environment, signing keys, SDK paths or generated platform outputs.

The proposal does not authorize changes to the deployment app, merging the two repositories, branch operations, pushes or deployments. The selected sources remain at their existing paths. Future consolidation must preserve fsfs improvements and the deployment history while keeping one clearly designated primary Flutter source.

## Exact normalized Dart path appendix

These are comparison paths, not a feature-count claim. Raw changed content and the unchanged normalized copies are private evidence under `.git/phase2-20261021`.

- `lib/core/repositories/admin_modules_repository.dart`
- `lib/core/repositories/agent_repository.dart`
- `lib/core/repositories/employee_repository.dart`
- `lib/core/repositories/parent_repository.dart`
- `lib/core/repositories/stories_repository.dart`
- `lib/core/repositories/student_repository.dart`
- `lib/core/repositories/university_repository.dart`
- `lib/core/services/auth_session.dart`
- `lib/core/services/error_reporter.dart`
- `lib/core/services/google_sign_in_service.dart`
- `lib/core/utils/app_error.dart`
- `lib/core/utils/country_data.dart`
- `lib/core/utils/password_policy.dart`
- `lib/core/utils/student_events.dart`
- `lib/core/widgets/app_components.dart`
- `lib/core/widgets/app_notice.dart`
- `lib/core/widgets/state_widgets.dart`
- `lib/main.dart`
- `lib/screens/applications_documents_payments/documents_screens.dart`
- `lib/screens/applications_documents_payments/payments_screens.dart`
- `lib/screens/auth/account_recovery_screen.dart`
- `lib/screens/auth/browser_sign_in_screen.dart`
- `lib/screens/auth/email_challenge_screen.dart`
- `lib/screens/auth/login_register_screens.dart`
- `lib/screens/community/student_community_hub.dart`
- `lib/screens/home_journey/calendar_screen.dart`
- `lib/screens/home_journey/global_search_screen.dart`
- `lib/screens/home_journey/journey_preview_card.dart`
- `lib/screens/home_journey/notifications_screen.dart`
- `lib/screens/home_journey/student_banner_carousel.dart`
- `lib/screens/profile_account/account_security_screen.dart`
- `lib/screens/profile_account/delete_account_screen.dart`
- `lib/screens/profile_account/edit_profile_screen.dart`
- `lib/screens/profile_account/notification_preferences_screen.dart`
- `lib/screens/profile_account/profile_account_screens.dart`
- `lib/screens/profile_account/security_settings_screen.dart`
- `lib/screens/profile_account/student_rewards_currency_screens.dart`
- `lib/screens/roles/admin_financials_marketing_screens.dart`
- `lib/screens/roles/admin_scholarships_screen.dart`
- `lib/screens/roles/admin_singleton_hub_screens.dart`
- `lib/screens/roles/admin_support_knowledge_screens.dart`
- `lib/screens/roles/admin_university_accounts_screen.dart`
- `lib/screens/roles/admin_users_access_screen.dart`
- `lib/screens/roles/agent_student_detail_screen.dart`
- `lib/screens/roles/employee_consultations_screen.dart`
- `lib/screens/roles/employee_dashboard_screen.dart`
- `lib/screens/roles/employee_extra_screens.dart`
- `lib/screens/roles/follow_up_reminders_screen.dart`
- `lib/screens/roles/parent_dashboard_screen.dart`
- `lib/screens/roles/university_application_review_screen.dart`
- `lib/screens/roles/university_dashboard_screen.dart`
- `lib/screens/services_support/alumni_directory_screen.dart`
- `lib/screens/services_support/bird_ai_screen.dart`
- `lib/screens/services_support/knowledge_base_screen.dart`
- `lib/screens/services_support/live_consultation_screen.dart`
- `lib/screens/services_support/services_consultation_screens.dart`
- `lib/screens/services_support/student_life_alumni_screens.dart`
- `lib/screens/services_support/student_listings_screen.dart`
- `lib/screens/stories/story_viewer.dart`
- `lib/screens/stories/story_viewers_screen.dart`
- `lib/screens/stories/student_stories.dart`
- `lib/screens/universities_programs_countries/catalog_detail.dart`
- `lib/screens/universities_programs_countries/compare_list_screen.dart`
- `lib/screens/universities_programs_countries/comparison_grid.dart`
- `lib/screens/universities_programs_countries/countries_scholarships_screens.dart`
- `lib/screens/universities_programs_countries/programs_screens.dart`
- `lib/screens/visa_travel_accommodation/accommodation_arrival_screens.dart`
- `lib/screens/visa_travel_accommodation/visa_travel_screens.dart`
- `test/apple_sign_in_test.dart`
- `test/application_document_updates_test.dart`
- `test/app_update_test.dart`
- `test/chat_controls_test.dart`
- `test/community_hub_test.dart`
- `test/design_review_test.dart`
- `test/document_library_test.dart`
- `test/journey_request_status_test.dart`
- `test/journey_requirements_test.dart`
- `test/journey_selector_design_test.dart`
- `test/password_session_replacement_test.dart`
- `test/post_admission_journey_test.dart`
- `test/story_viewers_test.dart`
- `test/story_viewer_test.dart`
- `test/student_public_profile_test.dart`
- `test/wink_game_test.dart`
- `test/wink_practice_test.dart`

Selected-only Dart path: `test/story_deletion_test.dart`. Deployment-only Dart paths: none.
