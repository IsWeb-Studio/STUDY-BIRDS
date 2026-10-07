import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/status_info.dart';

/// Context-aware parts of the student home, rendered from the server's
/// `home` payload (server/src/utils/studentHome.js): the context card
/// (PRD 96), important dates with countdowns (98) and the dashboard
/// sections (10). Navigation is delegated to the home screen via [onOpen],
/// which receives a destination key such as 'documents' or 'travel'.

String _s(dynamic value) => value == null ? '' : '$value';
Map<String, dynamic> _m(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String countdownLabel(int days) {
  if (days < 0) return 'متأخر ${-days} يوم';
  if (days == 0) return 'اليوم';
  if (days == 1) return 'غدًا';
  return 'بعد $days يوم';
}

/// The single most important card: what the student should do now.
class SmartHomeContextCard extends StatelessWidget {
  final Map<String, dynamic> home;
  final ValueChanged<String> onOpen;
  const SmartHomeContextCard(
      {super.key, required this.home, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final contextCard = _m(home['context']);
    final title = _s(contextCard['titleAr']);
    if (title.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('خطوتك الآن', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(title,
              style: AppTextStyles.cardTitle
                  .copyWith(fontSize: 18, color: AppColors.navy)),
          const SizedBox(height: 4),
          Text(_s(contextCard['descriptionAr']), style: AppTextStyles.body),
          const SizedBox(height: 12),
          PrimaryButton(
              label: title,
              expand: false,
              onPressed: () => onOpen(_s(contextCard['destination']))),
        ],
      ),
    );
  }
}

/// Upcoming and overdue dates, most urgent first, each with a countdown.
class SmartHomeDates extends StatelessWidget {
  final Map<String, dynamic> home;
  final ValueChanged<String> onOpen;
  const SmartHomeDates({super.key, required this.home, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final dates = (home['importantDates'] as List? ?? const [])
        .map(_m)
        .where((d) => DateTime.tryParse(_s(d['date'])) != null)
        .toList();
    final local = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('المواعيد المهمة', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 8),
        if (dates.isEmpty)
          const Text('لا توجد مواعيد قادمة حاليًا.',
              style: AppTextStyles.caption),
        for (final d in dates)
          Builder(builder: (context) {
            final overdue = d['overdue'] == true;
            final critical = d['critical'] == true;
            final color = overdue
                ? AppColors.danger
                : critical
                    ? AppColors.warning
                    : AppColors.navy;
            final days = (d['daysLeft'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: overdue || critical
                            ? color.withValues(alpha: 0.5)
                            : AppColors.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpen(_s(d['destination'])),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(Icons.event_outlined, color: color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s(d['titleAr']),
                                style: AppTextStyles.body
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                                local.formatMediumDate(
                                    DateTime.parse(_s(d['date'])).toLocal()),
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(countdownLabel(days),
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Admission, documents, visa, travel, payments, support, notifications and
/// recent activity — each only when it has something to say.
class SmartHomeSections extends StatelessWidget {
  final Map<String, dynamic> home;
  final ValueChanged<String> onOpen;
  const SmartHomeSections(
      {super.key, required this.home, required this.onOpen});

  Widget _tile(String title, List<String> lines, String destination,
          {Color? accent}) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpen(destination),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                for (final (index, line) in lines.indexed)
                  Text(line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                          fontWeight:
                              index == 0 ? FontWeight.w600 : FontWeight.w400,
                          color: index == 0 && accent != null ? accent : null)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sections = _m(home['sections']);
    final local = MaterialLocalizations.of(context);
    String date(dynamic raw) {
      final parsed = DateTime.tryParse(_s(raw));
      return parsed == null ? '' : local.formatMediumDate(parsed.toLocal());
    }

    final tiles = <Widget>[];
    final admission = StatusInfo.of(_m(sections['admission']));
    if (admission != null) {
      tiles.add(_tile(
          'حالة القبول', [admission.label, admission.meaning], 'applications',
          accent: admission.color));
    }
    final docs = _m(sections['documents']);
    final needsAction = (docs['needsAction'] as num?)?.toInt() ?? 0;
    tiles.add(_tile(
        'المستندات',
        [
          needsAction > 0
              ? '$needsAction يحتاج إجراء منك'
              : '${docs['approved'] ?? 0} معتمد من ${docs['total'] ?? 0}',
          if ((docs['underReview'] as num? ?? 0) > 0)
            '${docs['underReview']} قيد المراجعة',
        ],
        'documents',
        accent: needsAction > 0 ? AppColors.warning : null));
    final visa = _m(sections['visa']);
    if (visa.isNotEmpty) {
      tiles.add(_tile(
          'التأشيرة',
          [
            _s(visa['labelAr']),
            if (date(visa['appointmentDate']).isNotEmpty)
              'موعد السفارة: ${date(visa['appointmentDate'])}',
          ],
          'visa'));
    }
    final travel = _m(sections['travel']);
    if (travel.isNotEmpty) {
      final lines = [
        if (date(travel['arrivalDate']).isNotEmpty)
          'الوصول: ${date(travel['arrivalDate'])}',
        if (date(travel['moveInDate']).isNotEmpty)
          'بدء السكن: ${date(travel['moveInDate'])}',
      ];
      tiles.add(_tile('السفر والسكن',
          lines.isEmpty ? ['تابع طلب الوصول والسكن'] : lines, 'travel'));
    }
    final payments = _m(sections['payments']);
    final unpaid = (payments['unpaid'] as num?)?.toInt() ?? 0;
    final overdue = (payments['overdue'] as num?)?.toInt() ?? 0;
    tiles.add(_tile(
        'المدفوعات',
        [
          unpaid == 0 ? 'لا توجد مستحقات' : '$unpaid فاتورة غير مسددة',
          if (overdue > 0) '$overdue متأخرة',
        ],
        'payments',
        accent: overdue > 0 ? AppColors.danger : null));
    final support =
        (_m(sections['support'])['openTickets'] as num?)?.toInt() ?? 0;
    tiles.add(_tile(
        'الدعم',
        [support == 0 ? 'لا توجد تذاكر مفتوحة' : '$support تذكرة مفتوحة'],
        'support'));
    final notifications = _m(sections['notifications']);
    final unread = (notifications['unread'] as num?)?.toInt() ?? 0;
    tiles.add(_tile(
        'الإشعارات',
        [
          unread == 0 ? 'لا جديد' : '$unread غير مقروء',
          if (_s(_m(notifications['latest'])['title']).isNotEmpty)
            _s(_m(notifications['latest'])['title']),
        ],
        'notifications'));

    final activity =
        (sections['recentActivity'] as List? ?? const []).map(_m).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('أقسام رحلتك', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final tile in tiles) SizedBox(width: width, child: tile)
            ],
          );
        }),
        if (activity.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('آخر النشاطات', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 6),
          for (final item in activity)
            InkWell(
              onTap: () => onOpen(_s(item['destination'])),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.history_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(_s(item['titleAr']), style: AppTextStyles.body)),
                  Text(date(item['at']), style: AppTextStyles.caption),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}
