import 'dart:async';
import 'core/services/auth_session.dart';
import 'l10n/l10n.dart';
import 'screens/ai/birds_ai_screen.dart';
import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/utils/responsive.dart';
import 'screens/home_journey/home_dashboard_screen.dart';
import 'screens/home_journey/journey_tracker_screen.dart';
import 'screens/universities_programs_countries/explore_hub_screen.dart';
import 'screens/services_support/services_consultation_screens.dart';
import 'screens/community/student_community_hub.dart';
import 'screens/games/wink_screen.dart';
import 'screens/profile_account/profile_account_screens.dart';
import 'core/widgets/profile_bottom_navigation.dart';

/// Tab indexes for the main bottom navigation.
const int kTabHome = 0;
const int kTabJourney = 1;
const int kTabExplore = 2;
const int kTabServices = 3;
const int kTabCommunity = 4;
const int kTabGame = 5;
const int kTabAccount = 6;

/// Switch the main bottom nav to [index] from anywhere in the app.
void switchToMainTab(int index) => _StudentAppShellState.switchTab(index);

/// The connected student experience: one shared bottom nav, real navigation
/// between screens (tap a card → see the actual next screen), instead of
/// the flat screens-gallery list. This is what a client demo should run.
class StudentAppShell extends StatefulWidget {
  const StudentAppShell({super.key});

  @override
  State<StudentAppShell> createState() => _StudentAppShellState();
}

class _StudentAppShellState extends State<StudentAppShell> {
  static _StudentAppShellState? _instance;

  static void switchTab(int index) {
    if (index < 0 || index > kTabAccount) return;
    _instance?.setState(() => _instance!._index = index);
  }

  int _index = 0;
  Timer? _communityWarmup;

  List<_NavItemData> _items(BuildContext context) => [
        _NavItemData(icon: Icons.home_rounded, label: context.l10n.tabHome),
        _NavItemData(
            icon: Icons.timeline_rounded, label: context.l10n.tabJourney),
        _NavItemData(
            icon: Icons.explore_outlined, label: context.l10n.tabExplore),
        _NavItemData(
            icon: Icons.miscellaneous_services_outlined,
            label: context.l10n.tabServices),
        _NavItemData(
            icon: Icons.forum_outlined,
            label: Localizations.localeOf(context).languageCode == 'ar'
                ? 'مجتمع الطلاب'
                : 'Community'),
        _NavItemData(
            icon: Icons.sports_esports_outlined,
            label: Localizations.localeOf(context).languageCode == 'ar'
                ? 'الغمّازة'
                : 'Winker'),
      ];

  @override
  void initState() {
    super.initState();
    _instance = this;
    _communityWarmup = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          _index == kTabHome &&
          AuthSession.instance.token != null &&
          (ModalRoute.isCurrentOf(context) ?? true) &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        unawaited(warmCommunity());
      }
    });
  }

  @override
  void dispose() {
    _communityWarmup?.cancel();
    if (_instance == this) _instance = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _items(context);
    final tabs = [
      HomeDashboardScreen(embedInShell: true, isActive: _index == kTabHome),
      JourneyTrackerScreen(isActive: _index == kTabJourney),
      const ExploreHubScreen(),
      const ServicesCenterScreen(),
      StudentCommunityHub(isActive: _index == kTabCommunity),
      WinkScreen(
          isActive: _index == kTabGame,
          embedInShell: true,
          onBack: () => switchTab(kTabHome)),
      _index == kTabAccount ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    final content = IndexedStack(index: _index, children: tabs);
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        body: MaxWidthBody(maxWidth: 960, child: content),
        floatingActionButton: _index == kTabGame
            ? null
            : FloatingActionButton(
                key: const ValueKey('main-tabs-ai-button'),
                tooltip: 'Bird AI',
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.orange,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BirdsAiScreen(),
                    fullscreenDialog: true)),
                child: const Icon(Icons.auto_awesome_rounded),
              ),
        bottomNavigationBar: AdaptiveBottomBar(
            backgroundColor: Colors.transparent,
            child: ProfileBottomNavigation(
              currentIndex: _index,
              labels: [
                ...navItems.map((item) => item.label),
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'حسابي'
                    : 'Account'
              ],
              onTap: (i) => setState(() => _index = i),
            )),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}
