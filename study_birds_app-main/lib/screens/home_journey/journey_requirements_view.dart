import '../../core/widgets/app_notice.dart';
import 'journey_timeline_widgets.dart';
import '../../core/repositories/student_repository.dart';
import 'important_dates_screen.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    if (journeys.isEmpty) {
      return AppScaffold(
        title: 'رحلتي',
        showBackButton: Navigator.of(context).canPop(),
        body: EmptyState(
          icon: Icons.route_rounded,
          title: 'لم تبدأ رحلة تقديم بعد',
          message: 'اختر برنامجك الدراسي وقدّم طلبك لتظهر متطلباته هنا.',
          ctaLabel: 'استكشف الجامعات',
          onCta: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExploreHubScreen())),
        ),
      );
    }

    if (journeys.length == 1) {
      return _JourneyDetailScreen(
          journey: journeys.first, onRefresh: onRefresh);
    }

    // Multiple journeys: show selector screen
    return AppScaffold(
      title: 'رحلاتي',
      showBackButton: Navigator.of(context).canPop(),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.navy,
        child: ListView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (final journey in journeys)
              _JourneyCard(
                journey: journey,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _JourneyDetailScreen(
                        journey: journey, onRefresh: onRefresh))),
              ),
          ],
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final Map<String, dynamic> journey;
  final VoidCallback onTap;
  const _JourneyCard({required this.journey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stages =
        (journey['stages'] as List? ?? []).whereType<Map>().toList();
    final required =
        stages.where((s) => s['status'] != 'not-required').toList();
    final completed =
        required.where((s) => s['status'] == 'completed').length;
    final total = required.length;
    final progress = total > 0 ? completed / total : 0.0;
    final closed = journey['closed'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  journey['title'] as String? ?? 'رحلتك الدراسية',
                  style: AppTextStyles.cardTitle,
                ),
              ),
              if (closed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neutral.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('منتهية',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: closed ? AppColors.neutral : AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completed من $total مرحلة مكتملة',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyDetailScreen extends StatelessWidget {
  final Map<String, dynamic> journey;
  final Future<void> Function() onRefresh;
  const _JourneyDetailScreen(
      {required this.journey, required this.onRefresh});

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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
              content: Text(
                  'تعذر تحميل الطلب. اسحب لتحديث الرحلة ثم أعد المحاولة.')));
        }
        return;
      }
      if (!context.mounted) return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (context.mounted) await onRefresh();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: journey['title'] as String? ?? 'رحلتي',
        showBackButton: Navigator.of(context).canPop(),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'خيارات الرحلة',
            onSelected: (value) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => value == 'dates'
                    ? const ImportantDatesScreen()
                    : value == 'calendar'
                        ? const CalendarScreen()
                        : const ArrivalServicesScreen())),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'dates', child: Text('المواعيد المهمة')),
              PopupMenuItem(value: 'calendar', child: Text('التقويم')),
              PopupMenuItem(value: 'arrival', child: Text('خدمات الوصول')),
            ],
          )
        ],
        body: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.navy,
            child: ListView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ..._journeyWidgets(context, journey),
              ],
            )),
      );

  List<Widget> _journeyWidgets(
      BuildContext context, Map<String, dynamic> journey) {
    final stages = (journey['stages'] as List? ?? []).whereType<Map>().toList();
    final required =
        stages.where((stage) => stage['status'] != 'not-required').toList();
    final completed =
        required.where((stage) => stage['status'] == 'completed').length;
    final currentIndex = journey['closed'] == true
        ? -1
        : stages.indexWhere((stage) => ![
              'completed',
              'not-required',
              'not-started',
              'upcoming'
            ].contains(stage['status']));
    return [
      JourneySummaryCard(
          title: journey['title'] as String? ?? 'رحلتك الدراسية',
          completed: completed,
          total: required.length),
      const SizedBox(height: 22),
      for (var i = 0; i < stages.length; i++)
        _stage(context, journey, stages[i], i,
            current: i == currentIndex, last: i == stages.length - 1),
      if (journey['closed'] == true)
        const Text('طلب منتهٍ — للمتابعة والأرشفة',
            style: AppTextStyles.caption),
      if (journey['followUp'] is Map) ...[
        const SizedBox(height: 8),
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
              style: TextStyle(color: AppColors.danger, fontSize: 12)),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
          onPressed: () => open(
              context, 'applications', journey['applicationId'] as String?),
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
      const SizedBox(height: 24),
    ];
  }

  Widget _stage(BuildContext context, Map journey, Map stage, int index,
      {required bool current, required bool last}) {
    final status = stage['status'];
    final description = stage['descriptionAr'] as String? ?? '';
    final showDescription =
        current || ['action-required', 'overdue', 'rejected'].contains(status);
    final details = <Widget>[
      if (stage['completedSubCount'] is int && stage['totalSubCount'] is int)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${stage['completedSubCount']} / ${stage['totalSubCount']} مراحل مكتملة',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: stage['completedSubCount'] == stage['totalSubCount']
                  ? const Color(0xFF16A34A)
                  : AppColors.navy,
            ),
          ),
        ),
      if (showDescription && description.isNotEmpty)
        Text(description,
            style: AppTextStyles.caption.copyWith(fontSize: 11, height: 1.6)),
      if (stage['dueAt'] is String)
        Text('موعد المرحلة: ${followUpDate(context, stage['dueAt'])}',
            style: AppTextStyles.caption),
      if ((stage['reference'] as String? ?? '').isNotEmpty)
        Text('مرجع التحقق: ${stage['reference']}',
            style: AppTextStyles.caption),
      if (status == 'overdue' && stage['recordedStatus'] != null)
        Text('بانتظار: ${label(stage['recordedStatus'])}',
            style: AppTextStyles.caption),
      if (journey['closed'] != true &&
          stage['destination'] == 'support' &&
          !['completed', 'not-required'].contains(stage['recordedStatus']))
        TextButton.icon(
            onPressed: () => open(context, 'support'),
            icon: const Icon(Icons.support_agent, size: 16),
            label: Text('تواصل بشأن ${stage['titleAr'] ?? 'المرحلة'}')),
    ];
    return JourneyTimelineTile(
      number: index + 1,
      title: stage['titleAr'] as String? ?? '',
      completed: status == 'completed',
      current: current,
      last: last,
      alert: ['overdue', 'rejected'].contains(status),
      statusLabel: label(status),
      onTap: stage['destination'] == null
          ? null
          : () => open(context, stage['destination'] as String?,
              journey['applicationId'] as String?),
      details: details.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: details),
    );
  }

  String followUpDate(BuildContext context, String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'غير محدد';
    return '${MaterialLocalizations.of(context).formatMediumDate(date)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  String label(dynamic status) =>
      const {
        'completed': 'مكتملة',
        'not-started': 'قادمة',
        'in-progress': 'جارية الآن',
        'not-required': 'غير مطلوبة',
        'waiting': 'بانتظار المراجعة',
        'waiting-team': 'بانتظار فريق Study Birds',
        'waiting-university': 'بانتظار الجامعة',
        'action-required': 'مطلوب منك',
        'overdue': 'متأخرة',
        'rejected': 'غير مقبول',
        'not-issued': 'لم تصدر فاتورة',
        'partial': 'مدفوع جزئياً',
      }[status] ??
      'قيد المتابعة';
  Color color(dynamic status) => status == 'completed'
      ? AppColors.success
      : ['overdue', 'rejected'].contains(status)
          ? AppColors.danger
          : status == 'action-required'
              ? AppColors.orange
              : status == 'partial'
                  ? AppColors.info
                  : AppColors.neutral;
}
