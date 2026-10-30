import '../config/app_theme.dart';
import 'package:flutter/material.dart';

Color? studentAchievementRing(int points) => points >= 100000
    ? AppColors.navy
    : points >= 10000
        ? AppColors.greenInk
        : null;

/// Cosmetic points achievement; this does not indicate identity verification.
class StudentAchievementMark extends StatelessWidget {
  final int points;
  const StudentAchievementMark({super.key, required this.points});
  @override
  Widget build(BuildContext context) => points < 200000
      ? const SizedBox.shrink()
      : Tooltip(
          message: 'شارة إنجاز 200,000 نقطة • علامة شكلية',
          child: Semantics(
              label: 'شارة إنجاز بالنقاط، وليست توثيق هوية',
              child: const Icon(Icons.verified_rounded,
                  key: ValueKey('cosmetic-achievement-badge'),
                  color: AppColors.greenInk,
                  size: 20)),
        );
}
