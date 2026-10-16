import '../../core/utils/json_safe.dart';
import 'journey_preview_card.dart';
import 'journey_selection_card.dart';
import '../../core/utils/status_info.dart';
import 'journey_timeline_widgets.dart';
import 'important_dates_screen.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../applications_documents_payments/applications_screens.dart';
import '../applications_documents_payments/payments_screens.dart';
import '../services_support/support_team_ai_screens.dart';
import 'calendar_screen.dart';
import '../visa_travel_accommodation/arrival_services_screen.dart';
import '../../app_shell.dart';

class JourneyRequirementsView extends StatelessWidget {
  final List<Map<String, dynamic>> journeys;
  final List<Map<String, dynamic>> applications;
  final Future<void> Function() onRefresh;
  final Widget Function(Map<String, dynamic>)? detailBuilder;
  const JourneyRequirementsView(
      {super.key,
      required this.journeys,
      required this.onRefresh,
      this.detailBuilder,
      this.applications = const []});

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
          onCta: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            switchToMainTab(kTabExplore);
          },
        ),
      );
    }

    if (journeys.length == 1) {
      return _JourneyDetailScreen(
          journey: journeys.first,
          application: _applicationFor(journeys.first),
          onRefresh: onRefresh);
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
                number: journeys.indexOf(journey) + 1,
                totalJourneys: journeys.length,
                application: applications
                        .where((app) =>
                            app['_id']?.toString() ==
                            journey['applicationId']?.toString())
                        .firstOrNull ??
                    const {},
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        detailBuilder?.call(journey) ??
                        _JourneyDetailScreen(
                            journey: journey,
                            application: _applicationFor(journey),
                            onRefresh: onRefresh))),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _applicationFor(Map<String, dynamic> journey) =>
      applications
          .where((app) =>
              app['_id']?.toString() == journey['applicationId']?.toString())
          .firstOrNull;
}

/// Makes a submitted request visible before the team has responded.
class JourneyRequestStatusCard extends StatelessWidget {
  final Map<String, dynamic> journey;
  const JourneyRequestStatusCard({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    final status = journey['applicationStatus'];
    final (String, String, IconData, Color)? content = switch (status) {
      'submitted' || 'pending' => (
          'طلبك قيد الانتظار',
          'تم استلام طلبك بنجاح، وهو بانتظار مراجعة فريق القبول. ستظهر تحديثات الطلب هنا فور توفرها.',
          Icons.hourglass_top_rounded,
          AppColors.orange
        ),
      'under-review' => (
          'طلبك قيد المراجعة',
          'تجري مراجعة طلبك حاليًا. يمكنك متابعة حالته هنا، وسنبلغك إذا احتجنا معلومات إضافية.',
          Icons.manage_search_rounded,
          AppColors.info
        ),
      'draft' || 'ready-to-apply' => (
          'طلبك بحاجة إلى استكمال',
          'راجع بيانات الطلب والمستندات وأكمل إرساله حتى يبدأ فريق القبول بمراجعته.',
          Icons.edit_note_rounded,
          AppColors.warning
        ),
      'additional-documents-required' => (
          'مطلوب استكمال المستندات',
          'طلب الفريق مستندات إضافية. افتح مراجعة الطلب والمستندات أدناه للاطلاع على المطلوب ورفعه.',
          Icons.upload_file_rounded,
          AppColors.warning
        ),
      _ => null,
    };
    if (content == null || journey['closed'] == true) {
      return const SizedBox.shrink();
    }
    final (title, message, icon, color) = content;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTextStyles.cardTitle.copyWith(color: color)),
              const SizedBox(height: 6),
              Text(message, style: AppTextStyles.body.copyWith(height: 1.7)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final Map<String, dynamic> journey, application;
  final int number, totalJourneys;
  final VoidCallback onTap;
  const _JourneyCard(
      {required this.journey,
      required this.application,
      required this.number,
      required this.totalJourneys,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stages = (Json.listOrNull(journey['stages']) ?? [])
        .whereType<Map>()
        .where((s) => s['status'] != 'not-required')
        .toList();
    final completed = stages.where((s) => s['status'] == 'completed').length;
    final current = stages.where((s) => s['status'] != 'completed').firstOrNull;
    final program = Json.mapOrNull(application['program']) ?? {};
    final university = Json.mapOrNull(program['university']) ?? {};
    final country = Json.mapOrNull(university['country']) ?? {};
    final closed = journey['closed'] == true;
    final status = closed
        ? 'منتهية'
        : StatusInfo.of(application)?.label ??
            journeyStatusLabel(journey['applicationStatus']?.toString() ??
                application['status']?.toString());
    return JourneySelectionCard(
      title:
          '${journey['title'] ?? program['title'] ?? program['name'] ?? 'رحلتك الدراسية'}',
      university: '${university['name'] ?? ''}',
      location: [country['nameAr'] ?? country['name'], university['city']]
          .where((v) => v != null && '$v'.trim().isNotEmpty)
          .join(' · '),
      status: status,
      number: number,
      currentStage: closed
          ? 'انتهت الرحلة'
          : current?['titleAr']?.toString() ??
              (stages.isNotEmpty ? 'اكتملت الرحلة' : status),
      completedStages: completed,
      totalStages: stages.length,
      onTap: onTap,
    );
  }
}

class _JourneyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> journey;
  final Map<String, dynamic>? application;
  final Future<void> Function() onRefresh;
  const _JourneyDetailScreen(
      {required this.journey, this.application, required this.onRefresh});

  @override
  State<_JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<_JourneyDetailScreen> {
  bool _opening = false;
  Map<String, dynamic> get journey => widget.journey;
  Future<void> onRefresh() => widget.onRefresh();

  Future<void> open(BuildContext context, String? destination,
      [String? applicationId]) async {
    // Lock synchronously before navigation so repeated taps in the same frame
    // cannot stack routes or start duplicate loads. Keep locked until return.
    if (_opening || !mounted) return;
    setState(() => _opening = true);
    try {
      Widget screen = destination == 'payments'
          ? const PaymentsSummaryScreen()
          : destination == 'support'
              ? const SupportCenterScreen()
              : const ApplicationsListScreen();
      if (destination == 'applications' && applicationId != null) {
        final application = widget.application;
        screen = application != null &&
                application['_id']?.toString() == applicationId
            ? ApplicationDetailScreen(application: application)
            : ApplicationDetailScreen.byId(applicationId: applicationId);
      }
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => screen));
      if (context.mounted) await onRefresh();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
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
    final stages =
        (Json.listOrNull(journey['stages']) ?? []).whereType<Map>().toList();
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
      JourneyRequestStatusCard(journey: journey),
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
          onPressed: _opening
              ? null
              : () => open(
                  context, 'applications', journey['applicationId'] as String?),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('مراجعة الطلب والمستندات')),
      if (journey['nextAction'] is Map &&
          journey['nextAction']['destination'] == 'payments')
        FilledButton.icon(
            onPressed: _opening ? null : () => open(context, 'payments'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('مراجعة المدفوعات')),
      if (journey['nextAction'] is Map &&
          journey['nextAction']['destination'] == 'support')
        OutlinedButton(
            onPressed: _opening ? null : () => open(context, 'support'),
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
            onPressed: _opening ? null : () => open(context, 'support'),
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
      onTap: _opening || stage['destination'] == null
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
