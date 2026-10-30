# Flutter analysis remediation ? Phase 5

Deployment scope: D:/work/studybirds_session_release/app. Historical Phase 4 flutter analyze: 279 info, 0 warnings/errors, exit 1. Fresh Dart machine analyzer before edits confirms 279 info; after edits 275 info, 0 warnings/errors. Dart analyze exits 0 for info-only findings; this must not be reported as a clean Flutter analyze pass. No rules disabled or severity thresholds changed.

## Rules, counts and risk

- unnecessary_import: 3 ? 0. Risk: low. Remove only analyzer-proven redundant directives; completed three.
- prefer_const_constructors: 125 ? 125. Risk: low, local review. Apply individual const opportunities with widget tests; defer broad changes.
- curly_braces_in_flow_control_structures: 119 ? 118. Risk: low for a single statement; medium in complex branches. Add explicit blocks without moving statements; one story early-return completed.
- deprecated_member_use: 7 ? 7. Risk: medium. Review SDK-specific replacement and visual/runtime differences before changing.
- use_super_parameters: 1 ? 1. Risk: low. Review constructor forwarding and defaults; defer unrelated API maintenance.
- sort_child_properties_last: 1 ? 1. Risk: low. Reorder only pure named argument expressions after checking side effects; deferred.
- prefer_const_literals_to_create_immutables: 20 ? 20. Risk: low, local review. Check identity-sensitive callers; scoped const conversion later.
- prefer_iterable_wheretype: 1 ? 1. Risk: medium. Verify filtering semantics, nulls and type inference; test before adopting.
- avoid_relative_lib_imports: 1 ? 1. Risk: low. Use package import after verifying package identity; deferred.
- avoid_print: 1 ? 1. Risk: low for CLI tool; behavior-sensitive output. Tool stdout is an observable interface; review logging contract rather than suppressing rule.

## Implemented four fixes

Removed redundant imports in integration/services_preview_test.dart, lib/screens/community/student_community_hub.dart and test/app_update_test.dart. Added braces to the existing story love early-return in lib/screens/stories/story_viewer.dart. Exact pre-edit bytes/hash manifests are in .git/phase5-20261021/source-before and edited-files.json. No broad reformatting, widget redesign, authentication/API/signing or dependency edit. Changes apply only to the deployment app; primary app source is unchanged.

Validation: actual deployment dart analyze --format=machine, exit 0, 275 INFO and zero warning/error; flutter test --no-pub test/story_viewer_test.dart test/app_update_test.dart --reporter expanded, exit 0, 22 passed. Analyzer covers the changed integration/community files; those flows were not device-tested. No full build/pub get. A separate incidental primary-app analyzer run also exited 0; deployment counts come only from the explicitly selected deployment cwd.

## Complete baseline inventory by file and rule

Line numbers below are BEFORE edits; cross-reference the rule risk/fix guidance above. Every one of the 279 baseline diagnostics is represented.

### integration/services_preview_test.dart

- unnecessary_import: 1; lines 2.

### lib/core/repositories/admin_modules_repository.dart

- prefer_const_constructors: 2; lines 15, 343.

### lib/core/repositories/agent_repository.dart

- prefer_const_constructors: 1; lines 13.

### lib/core/repositories/employee_repository.dart

- prefer_const_constructors: 1; lines 17.

### lib/core/repositories/parent_repository.dart

- prefer_const_constructors: 1; lines 12.

### lib/core/repositories/student_repository.dart

- prefer_const_constructors: 1; lines 176.
- curly_braces_in_flow_control_structures: 3; lines 203, 343, 360.

### lib/core/repositories/university_repository.dart

- prefer_const_constructors: 1; lines 14.

### lib/core/services/auth_session.dart

- prefer_const_constructors: 4; lines 894, 897, 900, 903.

### lib/core/services/google_sign_in_service.dart

- curly_braces_in_flow_control_structures: 1; lines 56.

### lib/core/utils/app_error.dart

- curly_braces_in_flow_control_structures: 2; lines 70, 101.

### lib/core/utils/country_data.dart

- deprecated_member_use: 1; lines 353.

### lib/core/utils/password_policy.dart

- curly_braces_in_flow_control_structures: 2; lines 20, 25.

### lib/core/utils/student_events.dart

- curly_braces_in_flow_control_structures: 1; lines 46.

### lib/core/widgets/app_notice.dart

- use_super_parameters: 1; lines 7.
- sort_child_properties_last: 1; lines 31.

### lib/core/widgets/state_widgets.dart

- prefer_const_constructors: 5; lines 18, 19, 21, 102, 103.
- prefer_const_literals_to_create_immutables: 1; lines 18.

### lib/main.dart

- curly_braces_in_flow_control_structures: 2; lines 249, 259.
- prefer_const_constructors: 4; lines 563, 574, 619, 668.

### lib/screens/applications_documents_payments/documents_screens.dart

- curly_braces_in_flow_control_structures: 8; lines 150, 156, 392, 398, 558, 906, 911, 954.
- deprecated_member_use: 1; lines 388.

### lib/screens/applications_documents_payments/payments_screens.dart

- prefer_const_constructors: 4; lines 406, 459, 465, 674.

### lib/screens/auth/account_recovery_screen.dart

- curly_braces_in_flow_control_structures: 4; lines 23, 26, 94, 96.
- prefer_const_constructors: 1; lines 27.

### lib/screens/auth/browser_sign_in_screen.dart

- curly_braces_in_flow_control_structures: 5; lines 41, 44, 61, 70, 75.

### lib/screens/auth/email_challenge_screen.dart

- prefer_const_constructors: 1; lines 75.

### lib/screens/auth/login_register_screens.dart

- curly_braces_in_flow_control_structures: 5; lines 318, 741, 762, 872, 928.
- prefer_const_constructors: 1; lines 550.

### lib/screens/community/student_community_hub.dart

- unnecessary_import: 1; lines 2.

### lib/screens/home_journey/calendar_screen.dart

- curly_braces_in_flow_control_structures: 3; lines 35, 37, 109.

### lib/screens/home_journey/global_search_screen.dart

- curly_braces_in_flow_control_structures: 2; lines 47, 76.

### lib/screens/home_journey/journey_preview_card.dart

- prefer_const_constructors: 2; lines 100, 100.

### lib/screens/home_journey/notifications_screen.dart

- curly_braces_in_flow_control_structures: 7; lines 113, 127, 154, 168, 197, 211, 274.
- deprecated_member_use: 1; lines 270.

### lib/screens/home_journey/student_banner_carousel.dart

- deprecated_member_use: 1; lines 83.

### lib/screens/profile_account/account_security_screen.dart

- prefer_const_constructors: 1; lines 75.

### lib/screens/profile_account/delete_account_screen.dart

- curly_braces_in_flow_control_structures: 1; lines 81.
- prefer_const_constructors: 1; lines 126.

### lib/screens/profile_account/edit_profile_screen.dart

- prefer_const_constructors: 1; lines 426.
- deprecated_member_use: 1; lines 624.

### lib/screens/profile_account/profile_account_screens.dart

- curly_braces_in_flow_control_structures: 8; lines 99, 688, 692, 699, 716, 730, 797, 803.
- prefer_const_constructors: 17; lines 134, 438, 450, 461, 474, 487, 498, 511, 523, 551, 566, 579, 605, 617, 717, 731, 804.

### lib/screens/profile_account/security_settings_screen.dart

- prefer_const_constructors: 3; lines 161, 296, 297.
- curly_braces_in_flow_control_structures: 3; lines 165, 220, 222.

### lib/screens/profile_account/student_rewards_currency_screens.dart

- prefer_const_constructors: 4; lines 558, 630, 641, 768.

### lib/screens/roles/admin_financials_marketing_screens.dart

- prefer_const_constructors: 1; lines 227.

### lib/screens/roles/admin_scholarships_screen.dart

- curly_braces_in_flow_control_structures: 5; lines 56, 64, 78, 84, 117.

### lib/screens/roles/admin_singleton_hub_screens.dart

- prefer_const_constructors: 1; lines 181.

### lib/screens/roles/admin_support_knowledge_screens.dart

- prefer_const_constructors: 2; lines 184, 201.

### lib/screens/roles/admin_university_accounts_screen.dart

- curly_braces_in_flow_control_structures: 3; lines 195, 263, 272.

### lib/screens/roles/admin_users_access_screen.dart

- prefer_const_constructors: 1; lines 159.

### lib/screens/roles/agent_student_detail_screen.dart

- prefer_const_constructors: 6; lines 197, 326, 327, 668, 674, 678.
- prefer_const_literals_to_create_immutables: 1; lines 328.

### lib/screens/roles/employee_consultations_screen.dart

- prefer_const_constructors: 1; lines 151.

### lib/screens/roles/employee_dashboard_screen.dart

- curly_braces_in_flow_control_structures: 4; lines 230, 231, 278, 279.
- prefer_const_constructors: 2; lines 303, 790.

### lib/screens/roles/employee_extra_screens.dart

- curly_braces_in_flow_control_structures: 1; lines 342.
- deprecated_member_use: 1; lines 452.

### lib/screens/roles/follow_up_reminders_screen.dart

- curly_braces_in_flow_control_structures: 1; lines 51.
- prefer_const_constructors: 1; lines 72.

### lib/screens/roles/parent_dashboard_screen.dart

- prefer_const_constructors: 5; lines 178, 268, 269, 1136, 1143.
- curly_braces_in_flow_control_structures: 1; lines 184.
- prefer_const_literals_to_create_immutables: 1; lines 270.

### lib/screens/roles/university_application_review_screen.dart

- prefer_const_constructors: 5; lines 98, 103, 375, 517, 518.
- prefer_iterable_wheretype: 1; lines 514.

### lib/screens/roles/university_dashboard_screen.dart

- prefer_const_constructors: 1; lines 74.

### lib/screens/services_support/alumni_directory_screen.dart

- prefer_const_constructors: 2; lines 55, 95.

### lib/screens/services_support/bird_ai_screen.dart

- prefer_const_constructors: 2; lines 137, 140.
- prefer_const_literals_to_create_immutables: 1; lines 137.

### lib/screens/services_support/knowledge_base_screen.dart

- curly_braces_in_flow_control_structures: 2; lines 297, 312.
- prefer_const_constructors: 2; lines 298, 313.

### lib/screens/services_support/live_consultation_screen.dart

- prefer_const_constructors: 1; lines 166.

### lib/screens/services_support/services_consultation_screens.dart

- curly_braces_in_flow_control_structures: 3; lines 189, 394, 510.
- prefer_const_constructors: 4; lines 227, 633, 666, 688.

### lib/screens/services_support/student_life_alumni_screens.dart

- prefer_const_constructors: 5; lines 85, 680, 692, 752, 1039.
- prefer_const_literals_to_create_immutables: 1; lines 752.
- curly_braces_in_flow_control_structures: 1; lines 1033.
- deprecated_member_use: 1; lines 1075.

### lib/screens/services_support/student_listings_screen.dart

- prefer_const_constructors: 1; lines 48.

### lib/screens/stories/story_viewer.dart

- curly_braces_in_flow_control_structures: 1; lines 660.

### lib/screens/stories/student_stories.dart

- prefer_const_constructors: 1; lines 258.
- prefer_const_literals_to_create_immutables: 1; lines 258.

### lib/screens/universities_programs_countries/catalog_detail.dart

- prefer_const_constructors: 2; lines 556, 558.

### lib/screens/universities_programs_countries/compare_list_screen.dart

- curly_braces_in_flow_control_structures: 3; lines 76, 85, 87.

### lib/screens/universities_programs_countries/comparison_grid.dart

- prefer_const_constructors: 3; lines 51, 53, 54.

### lib/screens/universities_programs_countries/countries_scholarships_screens.dart

- prefer_const_constructors: 2; lines 250, 342.
- prefer_const_literals_to_create_immutables: 1; lines 251.
- curly_braces_in_flow_control_structures: 3; lines 315, 321, 347.

### lib/screens/universities_programs_countries/programs_screens.dart

- prefer_const_constructors: 1; lines 140.

### lib/screens/visa_travel_accommodation/accommodation_arrival_screens.dart

- prefer_const_constructors: 5; lines 205, 217, 329, 420, 432.

### lib/screens/visa_travel_accommodation/visa_travel_screens.dart

- curly_braces_in_flow_control_structures: 8; lines 185, 451, 596, 748, 926, 934, 1164, 1172.
- prefer_const_constructors: 10; lines 284, 1006, 1036, 1058, 1098, 1253, 1278, 1307, 1336, 1357.

### test/app_update_test.dart

- unnecessary_import: 1; lines 3.

### test/apple_sign_in_test.dart

- curly_braces_in_flow_control_structures: 1; lines 91.

### test/application_document_updates_test.dart

- curly_braces_in_flow_control_structures: 2; lines 63, 95.

### test/chat_controls_test.dart

- curly_braces_in_flow_control_structures: 2; lines 41, 43.

### test/community_hub_test.dart

- curly_braces_in_flow_control_structures: 5; lines 55, 68, 70, 72, 81.

### test/design_review_test.dart

- curly_braces_in_flow_control_structures: 5; lines 76, 86, 88, 94, 109.

### test/document_library_test.dart

- curly_braces_in_flow_control_structures: 2; lines 54, 127.

### test/journey_request_status_test.dart

- prefer_const_literals_to_create_immutables: 1; lines 90.

### test/journey_requirements_test.dart

- prefer_const_literals_to_create_immutables: 8; lines 12, 13, 15, 16, 20, 21, 26, 47.

### test/journey_selector_design_test.dart

- prefer_const_constructors: 2; lines 14, 15.

### test/post_admission_journey_test.dart

- prefer_const_literals_to_create_immutables: 4; lines 51, 51, 52, 53.

### test/student_public_profile_test.dart

- curly_braces_in_flow_control_structures: 3; lines 52, 152, 158.

### test/wink_game_test.dart

- curly_braces_in_flow_control_structures: 4; lines 263, 268, 293, 295.

### test/wink_practice_test.dart

- curly_braces_in_flow_control_structures: 2; lines 23, 45.

### tool/check_error_policy.dart

- avoid_relative_lib_imports: 1; lines 2.
- avoid_print: 1; lines 56.
