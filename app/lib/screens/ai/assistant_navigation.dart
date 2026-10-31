import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/services/auth_session.dart';
import '../../core/services/locale_controller.dart';
import '../applications_documents_payments/applications_screens.dart';
import '../applications_documents_payments/documents_screens.dart';
import '../applications_documents_payments/payments_screens.dart';
import '../profile_account/profile_account_screens.dart'
    show ProfileScreen, SettingsScreen;
import '../profile_account/edit_profile_screen.dart';
import '../profile_account/security_settings_screen.dart';
import '../profile_account/student_rewards_currency_screens.dart';
import '../home_journey/notifications_screen.dart';
import '../home_journey/journey_tracker_screen.dart';
import '../universities_programs_countries/universities_screens.dart';
import '../universities_programs_countries/programs_screens.dart';
import '../universities_programs_countries/countries_scholarships_screens.dart'
    show CountriesExplorerScreen;
import '../universities_programs_countries/compare_list_screen.dart';
import '../universities_programs_countries/explore_hub_screen.dart'
    show FavoritesScreen;
import '../services_support/support_team_ai_screens.dart'
    show SupportCenterScreen;
import '../services_support/services_consultation_screens.dart';
import '../services_support/student_life_alumni_screens.dart';
import '../community/student_community_hub.dart';
import '../stories/friends_screen.dart';
import '../games/wink_screen.dart';

/// Logical action IDs, never URL strings, model code, IDs of student records,
/// or commands. These destinations only open existing screens.
class AssistantNavigation {
  static String? _appVersion;
  static Future<void>? _versionLoad;
  static Future<void> loadAppVersion() => _versionLoad ??= () async {
        try {
          final info = await PackageInfo.fromPlatform();
          final value = '${info.version}+${info.buildNumber}';
          if (RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(value)) {
            _appVersion = value;
          }
        } catch (_) {
          // Optional public package metadata; never invent a version or prevent help.
        }
      }();
  static const knowledgeVersion = '2026.10.23.3';
  // Content can evolve without changing the allowlisted navigation protocol.
  static const knowledgeRevision = '2026.10.31.4';
  static const ids = {
    'applications',
    'documents',
    'universities',
    'programs',
    'countries',
    'compare',
    'favorites',
    'profile',
    'passport',
    'settings',
    'security',
    'notifications',
    'support',
    'community',
    'friends',
    'game',
    'journey',
    'payments',
    'services',
    'scholarships',
    'events',
    'alumni',
    'rewards'
  };
  static bool allowed(String id, UserRole? role, String? version) =>
      role == UserRole.student &&
      version == knowledgeVersion &&
      ids.contains(id);
  static const labels = {
    'applications': ['طلباتي', 'My Applications'],
    'documents': ['مستنداتي', 'My Documents'],
    'universities': ['الجامعات', 'Universities'],
    'programs': ['البرامج', 'Programs'],
    'countries': ['الدول', 'Countries'],
    'compare': ['قائمة المقارنة', 'Comparison list'],
    'favorites': ['المفضلة', 'Favorites'],
    'profile': ['حسابي', 'My Account'],
    'passport': ['جواز السفر', 'Passport'],
    'settings': ['الإعدادات', 'Settings'],
    'security': ['الأمان', 'Security'],
    'notifications': ['الإشعارات', 'Notifications'],
    'support': ['مركز الدعم', 'Support Center'],
    'community': ['المجتمع', 'Community'],
    'friends': ['الأصدقاء', 'Friends'],
    'game': ['الغمّازة', 'The Winker'],
    'journey': ['رحلتي', 'My Journey'],
    'payments': ['ملخص المدفوعات', 'Payments summary'],
    'services': ['الخدمات', 'Services'],
    'scholarships': ['المنح الدراسية', 'Scholarships'],
    'events': ['الحياة الطلابية', 'Student life'],
    'alumni': ['شبكة الخريجين', 'Alumni network'],
    'rewards': ['المكافآت', 'Rewards'],
  };
  static Widget? destination(String id) => switch (id) {
        'applications' => const ApplicationsListScreen(),
        'documents' => const MyDocumentsScreen(),
        'universities' => const UniversitiesExplorerScreen(),
        'programs' => const ProgramsExplorerScreen(),
        'countries' => const CountriesExplorerScreen(),
        'compare' => const CompareListScreen(),
        'favorites' => const FavoritesScreen(),
        'profile' => const ProfileScreen(),
        'passport' => const EditProfileScreen(section: ProfileSection.passport),
        'settings' => const SettingsScreen(),
        'security' => const SecuritySettingsScreen(),
        'notifications' => const NotificationsScreen(),
        'support' => const SupportCenterScreen(),
        'community' => const StudentCommunityHub(),
        'friends' => const FriendsScreen(),
        'game' => const WinkScreen(),
        'journey' => const JourneyTrackerScreen(),
        'payments' => const PaymentsSummaryScreen(),
        'services' => const ServicesCenterScreen(),
        'scholarships' => const ScholarshipsScreen(),
        'events' => const StudentLifeOffersScreen(),
        'alumni' => const AlumniNetworkScreen(),
        'rewards' => const StudentRewardsScreen(),
        _ => null,
      };
  static Map<String, dynamic> context(String screen, String language) => {
        'screen': screen,
        'language': language,
        'knowledgeVersion': knowledgeVersion,
        'knowledgeRevision': knowledgeRevision,
        if (_appVersion != null) 'appVersion': _appVersion,
        'flags': {'englishEnabled': LocaleController.englishEnabled},
      };
}

class AssistantActions extends StatelessWidget {
  final List<dynamic> actions;
  final String? version;
  const AssistantActions(
      {super.key, required this.actions, required this.version});
  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    return Wrap(spacing: 8, children: [
      for (final action in actions.whereType<Map>())
        if (action['id'] is String &&
            AssistantNavigation.allowed(
                action['id'], session.currentUser?.role, version))
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            key: ValueKey('assistant-open-${action['id']}'),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            // The server label and text never become executable UI instructions.
            label: Text(Localizations.localeOf(context).languageCode == 'en'
                ? 'Open ${AssistantNavigation.labels[action['id']]![1]}'
                : 'فتح ${AssistantNavigation.labels[action['id']]![0]}'),
            onPressed: () {
              if (session.token == null ||
                  !AssistantNavigation.allowed(
                      action['id'], session.currentUser?.role, version)) {
                return;
              }
              final screen = AssistantNavigation.destination(action['id']);
              if (screen != null) {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => screen));
              }
            },
          ),
    ]);
  }
}
