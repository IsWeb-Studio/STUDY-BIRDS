import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/utils/responsive.dart';
import 'screens/home_journey/home_dashboard_screen.dart';
import 'screens/home_journey/journey_tracker_screen.dart';
import 'screens/universities_programs_countries/explore_hub_screen.dart';
import 'screens/services_support/services_consultation_screens.dart';
import 'screens/profile_account/profile_account_screens.dart';

/// Tab indexes for the main bottom navigation.
const int kTabHome = 0;
const int kTabJourney = 1;
const int kTabExplore = 2;
const int kTabServices = 3;
const int kTabProfile = 4;

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

  static void switchTab(int index) =>
      _instance?.setState(() => _instance!._index = index);

  int _index = 0;

  static const _navItems = [
    _NavItemData(icon: Icons.home_rounded, label: 'الرئيسية'),
    _NavItemData(icon: Icons.timeline_rounded, label: 'الرحلة'),
    _NavItemData(icon: Icons.explore_outlined, label: 'استكشاف'),
    _NavItemData(icon: Icons.miscellaneous_services_outlined, label: 'الخدمات'),
    _NavItemData(icon: Icons.person_outline_rounded, label: 'حسابي'),
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
    final tabs = [
      const HomeDashboardScreen(embedInShell: true),
      const JourneyTrackerScreen(),
      const ExploreHubScreen(),
      const ServicesCenterScreen(),
      const ProfileScreen(),
    ];

    final content = IndexedStack(index: _index, children: tabs);
    // Phones keep the bottom bar. Wider windows (tablets, iPad, split view)
    // switch to a side rail — the row's start side, so it sits on the right
    // in this RTL app — and the pages stay inside a readable max width.
    final wide = !Responsive.isCompact(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: wide
            ? Row(
                children: [
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.white,
                      indicatorColor: AppColors.orangeSoft,
                      selectedIconTheme:
                          const IconThemeData(color: AppColors.orange),
                      selectedLabelTextStyle: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                      unselectedLabelTextStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      destinations: [
                        for (final item in _navItems)
                          NavigationRailDestination(
                              icon: Icon(item.icon), label: Text(item.label)),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: MaxWidthBody(maxWidth: 960, child: content)),
                ],
              )
            : Column(children: [Expanded(child: content)]),
        bottomNavigationBar: wide
            ? null
            : _AnimatedBottomNav(
                currentIndex: _index,
                items: _navItems,
                onTap: (i) => setState(() => _index = i),
              ),
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
          height: 64,
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
                    child: InkWell(
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
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
