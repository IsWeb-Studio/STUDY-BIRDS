import 'screens/ai/assistant_avatar.dart';
import 'package:study_birds/screens/universities_programs_countries/explore_hub_screen.dart';
import 'l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/utils/responsive.dart';
import 'screens/screen.dart';
import 'core/widgets/profile_bottom_navigation.dart';

/// Stable destination IDs; only Home and Community appear in the bottom bar.
const int kTabHome = 0;
const int kTabDashboard = 0;
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
    _instance?.setState(() {
      _instance!._visited.add(index);
      _instance!._index = index;
    });
  }

  int _index = kTabHome;
  final Set<int> _visited = {kTabHome};

  List<_NavItemData> _items(BuildContext context) => [
        _NavItemData(icon: Icons.home_outlined, label: context.l10n.tabHome),
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
                : 'Student community'),
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
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _items(context);
    final tabs = [
      _visited.contains(kTabDashboard)
          ? HomeDashboardScreen(
              embedInShell: true, isActive: _index == kTabDashboard)
          : const SizedBox.shrink(),
      _visited.contains(kTabJourney)
          ? JourneyTrackerScreen(isActive: _index == kTabJourney)
          : const SizedBox.shrink(),
      _visited.contains(kTabExplore)
          ? const ExploreHubScreen()
          : const SizedBox.shrink(),
      _visited.contains(kTabServices)
          ? const ServicesCenterScreen()
          : const SizedBox.shrink(),
      _visited.contains(kTabCommunity)
          ? StudentCommunityScreen(embedded: true, actions: [
              IconButton(
                  tooltip: 'المحادثات',
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const StudentCommunityHub()))),
            ])
          : const SizedBox.shrink(),
      WinkScreen(
          isActive: _index == kTabGame,
          embedInShell: true,
          onBack: () => switchTab(kTabHome)),
      _index == kTabAccount ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    final content = IndexedStack(index: _index, children: [
      for (var i = 0; i < tabs.length; i++)
        TickerMode(enabled: _index == i, child: tabs[i]),
    ]);
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        body: MaxWidthBody(maxWidth: 960, child: content),
        floatingActionButton: _index == kTabGame
            ? null
            : FloatingActionButton(
                heroTag: 'main-bird-ai',
                key: const ValueKey('main-tabs-ai-button'),
                tooltip: 'COVEY AI',
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.green,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BirdsAiScreen(
                            originScreen: const [
                          'dashboard',
                          'journey',
                          'explore',
                          'services',
                          'community',
                          'game',
                          'account'
                        ][_index]),
                    fullscreenDialog: true)),
                child: const AssistantAvatar(size: 36),
              ),
        bottomNavigationBar: AdaptiveBottomBar(
            backgroundColor: Colors.transparent,
            child: ProfileBottomNavigation(
              currentIndex: _index,
              visibleDestinations: const [
                kTabHome,
                kTabCommunity,
                kTabGame,
              ],
              labels: [
                ...navItems.map((item) => item.label),
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'حسابي'
                    : 'Account'
              ],
              onTap: switchTab,
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
