import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

const journeyGreen = Color(0xFF22B86A);
const journeyOrange = Color(0xFFF08A24);
const journeyGrey = Color(0xFF92959D);

class JourneySummaryCard extends StatelessWidget {
  final String title;
  final int completed;
  final int total;
  const JourneySummaryCard(
      {super.key,
      required this.title,
      required this.completed,
      required this.total});
  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBECF0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .035),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ]),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  AppTextStyles.cardTitle.copyWith(fontSize: 14, height: 1.6)),
          const SizedBox(height: 5),
          Text('$percent% مكتمل — $completed من $total مرحلة',
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ])),
        const SizedBox(width: 16),
        Semantics(
            label: 'إنجاز الرحلة $percent بالمئة',
            child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                      child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          color: journeyOrange,
                          backgroundColor: const Color(0xFFE8E9ED),
                          strokeCap: StrokeCap.round)),
                  Text('$percent%',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                ]))),
      ]),
    );
  }
}

class JourneyTimelineTile extends StatelessWidget {
  final int number;
  final String title;
  final String statusLabel;
  final bool completed;
  final bool current;
  final bool last;
  final bool alert;
  final Widget? details;
  final VoidCallback? onTap;
  const JourneyTimelineTile(
      {super.key,
      required this.number,
      required this.title,
      required this.statusLabel,
      this.completed = false,
      this.current = false,
      this.last = false,
      this.alert = false,
      this.details,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = alert
        ? AppColors.danger
        : completed
            ? journeyGreen
            : current
                ? journeyOrange
                : journeyGrey;
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 30,
          child: Column(children: [
            Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? journeyGreen : Colors.white,
                    border: Border.all(color: color, width: 1.8)),
                child: completed
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : Text('$number',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
            if (!last)
              Expanded(
                  child: Center(
                      child: Container(
                          width: 2,
                          color: completed
                              ? journeyGreen
                              : const Color(0xFFE3E5EB)))),
          ])),
      const SizedBox(width: 12),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: onTap == null
                            ? Text(title,
                                style: AppTextStyles.cardTitle.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: current
                                        ? journeyOrange
                                        : AppColors.textPrimary))
                            : InkWell(
                                onTap: onTap,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(title,
                                        style: AppTextStyles.cardTitle.copyWith(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: current
                                                ? journeyOrange
                                                : AppColors.textPrimary))))),
                    const SizedBox(width: 8),
                    Container(
                        constraints: const BoxConstraints(maxWidth: 125),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.3,
                                color: color,
                                fontWeight: FontWeight.w600))),
                  ]),
                  if (details != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: details!),
                ],
              ))),
    ]));
  }
}
