import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

/// A compact application folder for the journey tab, separate from home cards.
class JourneySelectionCard extends StatelessWidget {
  final String title, university, location, status, currentStage;
  final int number, completedStages, totalStages;
  final VoidCallback onTap;

  const JourneySelectionCard(
      {super.key,
      required this.title,
      required this.university,
      required this.location,
      required this.status,
      required this.currentStage,
      required this.number,
      required this.completedStages,
      required this.totalStages,
      required this.onTap});

  double get progress =>
      totalStages == 0 ? 0 : (completedStages / totalStages).clamp(0, 1);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFE2E8F0))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: AppColors.navy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                              'ملف الرحلة ${number.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(status,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12))),
                        ]),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: const Icon(Icons.school_outlined,
                                          color: AppColors.navy)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(title,
                                            style: AppTextStyles.cardTitle
                                                .copyWith(fontSize: 18)),
                                        if (university.isNotEmpty) ...[
                                          const SizedBox(height: 5),
                                          Text(university,
                                              style: AppTextStyles.body),
                                        ],
                                        if (location.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(location,
                                              style: AppTextStyles.caption),
                                        ],
                                      ])),
                                ]),
                            const SizedBox(height: 20),
                            Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FC),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Row(children: [
                                  SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox.expand(
                                                child: CircularProgressIndicator(
                                                    value: progress,
                                                    strokeWidth: 4,
                                                    backgroundColor:
                                                        const Color(0xFFE3E9F0),
                                                    color: AppColors.orange,
                                                    semanticsLabel:
                                                        'تقدم الرحلة',
                                                    semanticsValue:
                                                        '${(progress * 100).round()}')),
                                            Text('${(progress * 100).round()}%',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.navy)),
                                          ])),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        const Text('المرحلة الحالية',
                                            style: AppTextStyles.caption),
                                        const SizedBox(height: 4),
                                        Text(currentStage,
                                            style: AppTextStyles.cardTitle),
                                        const SizedBox(height: 4),
                                        Text(
                                            totalStages == 0
                                                ? 'بانتظار تحديد المراحل'
                                                : '$completedStages من $totalStages مراحل مكتملة',
                                            style: AppTextStyles.caption),
                                      ])),
                                ])),
                            const SizedBox(height: 14),
                            Row(children: [
                              const Icon(Icons.route_outlined,
                                  size: 18, color: AppColors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text('عرض المراحل والتفاصيل',
                                      style: AppTextStyles.body.copyWith(
                                          color: AppColors.navy,
                                          fontWeight: FontWeight.w700))),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 20, color: AppColors.navy),
                            ]),
                          ])),
                ]),
          ),
        ),
      );
}
