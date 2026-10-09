import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

/// Per-application summary sent by GET /students/applications as `card`
/// (server utils/applicationCard.js): intake, admission, payment and visa
/// status, assigned consultant, last update and next action (PRD 15/16).
class ApplicationCardFacts extends StatelessWidget {
  final Map<String, dynamic> card;

  /// Compact form for the applications list; the detail screen shows all rows.
  final bool compact;
  const ApplicationCardFacts(
      {super.key, required this.card, this.compact = false});

  static Map<String, dynamic>? of(Map<String, dynamic> application) =>
      application['card'] is Map
          ? Map<String, dynamic>.from(application['card'] as Map)
          : null;

  static Color _tone(dynamic tone) => switch ('$tone') {
        'action' => AppColors.warning,
        'danger' => AppColors.danger,
        'success' => AppColors.success,
        'neutral' => AppColors.neutral,
        _ => AppColors.info,
      };

  String _stage(String key) {
    final stage = card[key];
    return stage is Map ? '${stage['labelAr'] ?? ''}' : '';
  }

  Color? _stageColor(String key) {
    final stage = card[key];
    return stage is Map ? _tone(stage['tone']) : null;
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final lastUpdate = DateTime.tryParse('${card['lastUpdate']}')?.toLocal();
    final visa = card['visaStatus'];
    final next = card['nextAction'] is Map ? card['nextAction'] as Map : null;
    final rows = <(String, String, Color?)>[
      if (!compact && '${card['degreeLevel'] ?? ''}'.isNotEmpty)
        ('الدرجة', '${card['degreeLevel']}', null),
      if (!compact && '${card['campus'] ?? ''}'.isNotEmpty)
        ('الحرم الجامعي', '${card['campus']}', null),
      if ('${card['intake'] ?? ''}'.isNotEmpty)
        ('الفصل الدراسي', '${card['intake']}', null),
      ('القبول', _stage('admissionStatus'), _stageColor('admissionStatus')),
      if (!compact)
        (
          'المستندات',
          _stage('documentsStatus'),
          _stageColor('documentsStatus')
        ),
      ('الدفع', _stage('paymentStatus'), _stageColor('paymentStatus')),
      (
        'التأشيرة',
        visa is Map ? '${visa['labelAr'] ?? ''}' : 'لم تبدأ بعد',
        null
      ),
      ('المستشار', '${card['consultant'] ?? 'سيُعيَّن قريبًا'}', null),
      if (lastUpdate != null)
        ('آخر تحديث', local.formatMediumDate(lastUpdate), null),
    ].where((row) => row.$2.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final (label, value, color) in rows)
              Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$label: ', style: AppTextStyles.caption),
                    TextSpan(
                        text: value,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color ?? AppColors.textPrimary)),
                  ]),
                  softWrap: true),
          ],
        ),
        if (next != null && '${next['titleAr'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(10)),
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: next['waiting'] == true
                          ? 'بانتظار الفريق: '
                          : 'الخطوة التالية: ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '${next['titleAr']}'),
                ]),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ],
    );
  }
}
