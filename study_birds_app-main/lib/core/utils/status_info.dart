import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Plain-language status copy sent by the server with applications and
/// documents (`statusInfo`, built in server/src/constants/statusCatalog.js):
/// what the status means for the student now and what happens next.
/// Screens fall back to their local labels when an older server omits it.
class StatusInfo {
  final String status, code, tone, label, meaning, nextStep;
  const StatusInfo(
      {required this.status,
      required this.code,
      required this.tone,
      required this.label,
      required this.meaning,
      required this.nextStep});

  static StatusInfo? of(Map<String, dynamic>? item) {
    final raw = item?['statusInfo'];
    if (raw is! Map || raw['ar'] is! Map) return null;
    final ar = raw['ar'] as Map;
    final label = '${ar['label'] ?? ''}';
    if (label.isEmpty) return null;
    return StatusInfo(
        status: '${raw['status'] ?? ''}',
        code: '${raw['code'] ?? ''}',
        tone: '${raw['tone'] ?? 'info'}',
        label: label,
        meaning: '${ar['meaning'] ?? ''}',
        nextStep: '${ar['nextStep'] ?? ''}');
  }

  Color get color {
    switch (tone) {
      case 'success':
        return AppColors.success;
      case 'danger':
        return AppColors.danger;
      case 'action':
        return AppColors.warning;
      case 'neutral':
        return AppColors.neutral;
      default:
        return AppColors.info;
    }
  }
}

/// "What this means" + "Next step" card (PRD 103).
class StatusExplanationCard extends StatelessWidget {
  final StatusInfo info;
  const StatusExplanationCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: info.color.withValues(alpha: 0.35))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.label,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, color: info.color)),
            if (info.meaning.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(info.meaning, style: AppTextStyles.body),
            ],
            if (info.nextStep.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                        text: 'الخطوة التالية: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: info.nextStep),
                  ]),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textPrimary)),
            ],
          ],
        ),
      );
}
