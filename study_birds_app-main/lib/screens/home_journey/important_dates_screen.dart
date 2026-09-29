import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/analytics_service.dart';
import '../../core/student_events.dart';

class ImportantDatesScreen extends StatefulWidget {
  const ImportantDatesScreen({super.key});
  @override
  State<ImportantDatesScreen> createState() => _ImportantDatesScreenState();
}

class _ImportantDatesScreenState extends State<ImportantDatesScreen> {
  late Future<List<StudentEvent>> _future = loadCalendarEvents();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('important_dates');
  }

  void _refresh() => setState(() => _future = loadCalendarEvents());

  Color _colorForDays(int days) {
    if (days < 0) return AppColors.danger;
    if (days <= 3) return AppColors.danger;
    if (days <= 7) return AppColors.warning;
    if (days <= 30) return AppColors.orange;
    return AppColors.navy;
  }

  String _countdownLabel(int days) {
    if (days < 0) return 'تأخّر ${-days} يوم';
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غداً';
    return 'بعد $days يوم';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المواعيد المهمة',
      actions: [
        IconButton(
            onPressed: _refresh,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh)),
      ],
      body: FutureBuilder<List<StudentEvent>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()),
            );
          }
          if (snapshot.hasError) {
            return ErrorState(
                message: 'تعذر تحميل المواعيد', onRetry: _refresh);
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_rounded,
              title: 'لا توجد مواعيد مسجلة',
              message:
                  'ستظهر هنا مواعيد فواتيرك واستشاراتك وتاريخ وصولك بمجرد تسجيلها.',
            );
          }
          final now = DateTime.now();
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            color: AppColors.navy,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (_, i) {
                final event = events[i];
                final days = event.date.difference(now).inDays;
                final color = _colorForDays(days);
                final isPast = days < 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: BorderSide(
                          color: days <= 7
                              ? color.withValues(alpha: 0.4)
                              : AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Icon(
                              isPast
                                  ? Icons.event_busy_rounded
                                  : Icons.event_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title,
                                    style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700)),
                                if (event.detail.isNotEmpty)
                                  Text(event.detail,
                                      style: AppTextStyles.caption),
                                const SizedBox(height: 2),
                                Text(
                                  MaterialLocalizations.of(context)
                                      .formatMediumDate(event.date),
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _countdownLabel(days),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
