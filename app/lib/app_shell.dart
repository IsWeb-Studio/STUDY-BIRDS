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
import 'screens/games/wink_style.dart';

/// Tab indexes for the main bottom navigation.
const int kTabHome = 0;
const int kTabJourney = 1;
const int kTabExplore = 2;
const int kTabServices = 3;
const int kTabCommunity = 4;
const int kTabGame = 5;

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
    if (index < 0 || index > kTabGame) return;
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
            child: _AnimatedBottomNav(
          currentIndex: _index,
          items: navItems,
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

/// Custom bottom navigation bar: selected tab's icon scales up smoothly
/// (AnimatedScale) and a slim indicator bar slides beneath the active tab
/// (AnimatedAlign) instead of the flat default BottomNavigationBar.
class _AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onTap;

  const _AnimatedBottomNav(
      {required this.currentIndex, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (currentIndex == kTabGame) return _skyNavigation(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: SizedBox(
          height: 64 +
              (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0, 22),
          child: Stack(
            children: [
              // Sliding active indicator — a slim bar under the selected tab.
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment:
                    Alignment(1 - (2 * currentIndex) / (items.length - 1), -1),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 0),
                      height: 3,
                      width: 32,
                      decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (i) {
                  final selected = i == currentIndex;
                  final item = items[i];
                  return Expanded(
                    child: Semantics(
                        selected: selected,
                        button: true,
                        label: item.label,
                        child: InkWell(
                          key: ValueKey('main-tab-$i'),
                          onTap: () => onTap(i),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  scale: selected ? 1.15 : 1.0,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                  child: Icon(item.icon,
                                      color: selected
                                          ? AppColors.navy
                                          : AppColors.textSecondary,
                                      size: 24),
                                ),
                                const SizedBox(height: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 220),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: selected
                                        ? AppColors.navy
                                        : AppColors.textSecondary,
                                  ),
                                  child: Text(item.label,
                                      maxLines: i == kTabCommunity ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center),
                                ),
                              ],
                            ),
                          ),
                        )),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skyNavigation(BuildContext context) => ColoredBox(
      color: WinkSky.sky,
      child: SafeArea(
          top: false,
          child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12086EAB), blurRadius: 18)
                  ]),
              child: Row(
                  children: List.generate(items.length, (i) {
                final selected = i == currentIndex;
                final item = items[i];
                return Expanded(
                    child: Semantics(
                        selected: selected,
                        button: true,
                        label: item.label,
                        child: InkWell(
                            key: ValueKey('main-tab-$i'),
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => onTap(i),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                              color: selected
                                                  ? const Color(0xFFFFEEE3)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          child: Icon(
                                              selected
                                                  ? Icons.sports_esports_rounded
                                                  : item.icon,
                                              color: selected
                                                  ? WinkSky.orange
                                                  : WinkSky.muted,
                                              size: 23)),
                                      const SizedBox(height: 3),
                                      Text(item.label,
                                          maxLines: i == kTabCommunity ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: selected
                                                  ? WinkSky.orange
                                                  : WinkSky.muted,
                                              fontWeight: selected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                    ])))));
              })))));
}
