import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/analytics_service.dart';
import '../../core/student_events.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});
  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  late Future<List<StudentEvent>> future = loadActivityEvents();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('activity_log');
  }

  void _refresh() => setState(() => future = loadActivityEvents());

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('طلب') || t.contains('قبول')) return Icons.assignment_rounded;
    if (t.contains('مستند') || t.contains('وثيقة')) return Icons.description_rounded;
    if (t.contains('دفع') || t.contains('فاتورة')) return Icons.receipt_rounded;
    if (t.contains('إشعار') || t.contains('تنبيه')) return Icons.notifications_rounded;
    if (t.contains('استشارة')) return Icons.headset_mic_rounded;
    if (t.contains('تأشيرة')) return Icons.badge_rounded;
    return Icons.circle_outlined;
  }

  Color _colorFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('رفض') || t.contains('فشل')) return AppColors.danger;
    if (t.contains('قبول') || t.contains('موافق')) return AppColors.success;
    if (t.contains('انتهت') || t.contains('منتهية')) return AppColors.warning;
    return AppColors.navy;
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff <= 7) return 'منذ $diff أيام';
    if (diff <= 30) return 'منذ ${(diff / 7).round()} أسابيع';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'سجل الأنشطة',
        actions: [
          IconButton(
              onPressed: _refresh,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh)),
        ],
        body: FutureBuilder<List<StudentEvent>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonCard()));
            }
            if (snapshot.hasError) {
              return ErrorState(
                  message: 'تعذر تحميل الأنشطة', onRetry: _refresh);
            }
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return const EmptyState(
                  icon: Icons.history,
                  title: 'لا يوجد نشاط بعد',
                  message: 'ستظهر هنا طلباتك ومستنداتك وإشعاراتك.');
            }
            return RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await future;
              },
              color: AppColors.navy,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: events.length,
                itemBuilder: (_, i) {
                  final event = events[i];
                  final color = _colorFor(event.title);
                  final isLast = i == events.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: Icon(_iconFor(event.title),
                                    size: 16, color: color),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: AppColors.border,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                bottom: isLast ? 0 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(event.title,
                                          style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ),
                                    Text(_relativeDate(event.date),
                                        style: AppTextStyles.caption.copyWith(
                                            fontSize: 11)),
                                  ],
                                ),
                                if (event.detail.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(event.detail,
                                        style: AppTextStyles.caption),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}
