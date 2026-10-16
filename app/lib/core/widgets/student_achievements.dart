import 'package:flutter/material.dart';

Color? studentAchievementRing(int points) => points >= 100000
    ? const Color(0xFF8B5CF6)
    : points >= 10000
        ? Colors.orange
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
                  color: Color(0xFF2196F3),
                  size: 20)),
        );
}
