import '../../core/student_repository.dart';
import 'important_dates_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../applications_documents_payments/applications_screens.dart';
import '../applications_documents_payments/payments_screens.dart';
import '../services_support/support_team_ai_screens.dart';
import 'calendar_screen.dart';
import '../visa_travel_accommodation/arrival_services_screen.dart';
import '../universities_programs_countries/explore_hub_screen.dart';

class JourneyRequirementsView extends StatelessWidget {
  final List<Map<String, dynamic>> journeys;
  final Future<void> Function() onRefresh;
  const JourneyRequirementsView(
      {super.key, required this.journeys, required this.onRefresh});

  Future<void> open(BuildContext context, String? destination,
      [String? applicationId]) async {
    Widget screen = destination == 'payments'
        ? const PaymentsSummaryScreen()
        : destination == 'support'
            ? const SupportCenterScreen()
            : const ApplicationsListScreen();
    if (destination == 'applications' && applicationId != null) {
      try {
        final applications = await StudentRepository.instance.getApplications();
        final matches =
            applications.where((item) => item['_id'] == applicationId);
        if (matches.isEmpty) throw StateError('Application unavailable');
        screen = ApplicationDetailScreen(
            application: Map<String, dynamic>.from(matches.first as Map));
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'تعذر تحميل الطلب. اسحب لتحديث الرحلة ثم أعد المحاولة.')));
        return;
      }
      if (!context.mounted) return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (context.mounted) await onRefresh();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'رحلتي',
        showBackButton: false,
        actions: [
          IconButton(
              tooltip: 'المواعيد المهمة',
              icon: const Icon(Icons.event_note_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ImportantDatesScreen()))),
          IconButton(
              tooltip: 'التقويم',
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalendarScreen()))),
          IconButton(
              tooltip: 'خدمات الوصول',
              icon: const Icon(Icons.flight_land_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ArrivalServicesScreen()))),
        ],
        body: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.navy,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text('متابعة طلباتك خطوة بخطوة',
                    style: AppTextStyles.cardTitle),
                const SizedBox(height: 8),
                Text(
                    'تابع مستندات وفواتير كل طلب، ومراحل ما بعد القبول وفق تحديثات الفريق.',
                    style: AppTextStyles.caption),
                const SizedBox(height: 16),
                if (journeys.isEmpty)
                  Builder(builder: (context) => EmptyState(
                      icon: Icons.route_rounded,
                      title: 'لم تبدأ رحلة تقديم بعد',
                      message:
                          'اختر برنامجك الدراسي وقدّم طلبك لتظهر متطلباته هنا.',
                      ctaLabel: 'استكشف الجامعات',
                      onCta: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreHubScreen())))),
                for (final journey in journeys) ...[
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(journey['title'] as String? ?? 'طلب دراسي',
                            style: AppTextStyles.cardTitle),
                        if (journey['followUp'] is Map) ...[
                          const SizedBox(height: 12),
                          Text(
                              journey['followUp']['advisor'] is Map
                                  ? 'مسؤول المتابعة: ${journey['followUp']['advisor']['name']}'
                                  : 'لم يُعيّن مسؤول متابعة بعد',
                              style: AppTextStyles.caption),
                          if (journey['followUp']['dueAt'] is String)
                            Text(
                                'موعد المتابعة: ${followUpDate(context, journey['followUp']['dueAt'])}',
                                style: AppTextStyles.caption),
                          if (journey['followUp']['overdue'] == true)
                            const Text('تأخرت متابعة الفريق عن الموعد المحدد',
                                style: TextStyle(color: AppColors.danger)),
                        ],
                        if (journey['closed'] == true)
                          const Text('طلب منتهٍ — للمتابعة والأرشفة'),
                        if (journey['nextAction'] is Map) ...[
                          const SizedBox(height: 12),
                          Text(
                              journey['nextAction']['titleAr'] as String? ??
                                  'الخطوة التالية',
                              style: AppTextStyles.cardTitle
                                  .copyWith(color: AppColors.orange)),
                          const SizedBox(height: 4),
                          Text(
                              journey['nextAction']['descriptionAr']
                                      as String? ??
                                  '',
                              style: AppTextStyles.caption),
                        ],
                        for (final stage
                            in (journey['stages'] as List<dynamic>? ?? [])) ...[
                          const Divider(height: 28),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(
                                    stage['status'] == 'completed'
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: color(stage['status'])),
                                Text(stage['titleAr'] as String? ?? '',
                                    style: AppTextStyles.cardTitle),
                                StatusBadge(
                                    label: label(stage['status']),
                                    color: color(stage['status'])),
                              ]),
                          const SizedBox(height: 8),
                          Text(stage['descriptionAr'] as String? ?? '',
                              style: AppTextStyles.caption),
                          if (stage['dueAt'] is String)
                            Text(
                                'موعد المرحلة: ${followUpDate(context, stage['dueAt'])}',
                                style: AppTextStyles.caption),
                          if ((stage['reference'] as String? ?? '').isNotEmpty)
                            Text('مرجع التحقق: ${stage['reference']}',
                                style: AppTextStyles.caption),
                          if (stage['status'] == 'overdue' &&
                              stage['recordedStatus'] != null)
                            Text('بانتظار: ${label(stage['recordedStatus'])}',
                                style: AppTextStyles.caption),
                          if (journey['closed'] != true &&
                              stage['destination'] == 'support' &&
                              !['completed', 'not-required']
                                  .contains(stage['recordedStatus']))
                            TextButton.icon(
                                onPressed: () => open(context, 'support'),
                                icon: const Icon(Icons.support_agent),
                                label: Text(
                                    'تواصل بشأن ${stage['titleAr'] ?? 'المرحلة'}')),
                        ],
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                            onPressed: () => open(context, 'applications',
                                journey['applicationId'] as String?),
                            icon: const Icon(Icons.assignment_outlined),
                            label: const Text('مراجعة الطلب والمستندات')),
                        if (journey['nextAction'] is Map &&
                            journey['nextAction']['destination'] == 'payments')
                          FilledButton.icon(
                              onPressed: () => open(context, 'payments'),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('مراجعة المدفوعات')),
                        if (journey['nextAction'] is Map &&
                            journey['nextAction']['destination'] == 'support')
                          OutlinedButton(
                              onPressed: () => open(context, 'support'),
                              child: const Text('التواصل مع الفريق')),
                      ])),
                  const SizedBox(height: 16),
                ],
              ],
            )),
      );

  String followUpDate(BuildContext context, String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'غير محدد';
    return '${MaterialLocalizations.of(context).formatMediumDate(date)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  String label(dynamic status) =>
      const {
        'completed': 'مكتملة',
        'not-started': 'لم تبدأ',
        'in-progress': 'قيد التنفيذ',
        'not-required': 'غير مطلوبة',
        'waiting': 'بانتظار المراجعة',
        'waiting-team': 'بانتظار فريق Study Birds',
        'waiting-university': 'بانتظار الجامعة',
        'action-required': 'مطلوب منك',
        'overdue': 'متأخرة',
        'rejected': 'غير مقبول',
        'not-issued': 'لم تصدر فاتورة'
      }[status] ??
      'قيد المتابعة';
  Color color(dynamic status) => status == 'completed'
      ? AppColors.success
      : ['overdue', 'rejected'].contains(status)
          ? AppColors.danger
          : status == 'action-required'
              ? AppColors.orange
              : AppColors.neutral;
}
