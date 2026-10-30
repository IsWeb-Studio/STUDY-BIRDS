import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/current_user_avatar.dart';
import '../home_journey/home_dashboard_screen.dart' show showStudentMenu;
import '../home_journey/notifications_screen.dart';
import '../profile_account/profile_account_screens.dart';
import '../services_support/community_screen.dart';
import '../stories/student_stories.dart';
import 'student_community_hub.dart';

/// The student's landing page: account access, stories and the complete feed.
class StudentHomeScreen extends StatelessWidget {
  final bool isActive;
  final VoidCallback onOpenGame;
  const StudentHomeScreen(
      {super.key, this.isActive = true, required this.onOpenGame});
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return StudentCommunityScreen(
      embedded: true,
      actions: [
        IconButton(
            key: const ValueKey('student-home-menu'),
            tooltip: ar ? 'القائمة' : 'Menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => showStudentMenu(context)),
        IconButton(
            tooltip: ar ? 'الإشعارات' : 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NotificationsScreen()))),
        IconButton(
            key: const ValueKey('student-home-game'),
            tooltip: ar ? 'الغمّازة' : 'Winker',
            icon: const Icon(Icons.sports_esports_outlined),
            onPressed: onOpenGame),
        IconButton(
            tooltip: ar ? 'المحادثات' : 'Messages',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const StudentCommunityHub()))),
      ],
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Center(
            child: Tooltip(
              message: ar ? 'حسابي' : 'My account',
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('student-home-account'),
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.green, width: 2)),
                      child: const CurrentUserAvatar(radius: 40)),
                ),
              ),
            ),
          ),
        ),
        StudentStories(isActive: isActive, showCommunityButton: false),
      ]),
    );
  }
}
