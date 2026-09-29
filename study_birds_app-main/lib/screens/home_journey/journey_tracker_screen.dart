import 'journey_requirements_view.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/animations.dart';
import '../../core/student_repository.dart';
import '../../core/analytics_service.dart';
import 'calendar_screen.dart';
import 'important_dates_screen.dart';
import '../visa_travel_accommodation/arrival_services_screen.dart';

/// Per spec (point 12/13): the Journey is DYNAMIC — number and content of
/// stages can differ by country/university/service.
enum StageStatus { upcoming, inProgress, completed }

extension StageStatusX on StageStatus {
  String get label {
    switch (this) {
      case StageStatus.upcoming:
        return 'قادمة';
      case StageStatus.inProgress:
        return 'جارية الآن';
      case StageStatus.completed:
        return 'مكتملة';
    }
  }

  Color get color {
    switch (this) {
      case StageStatus.completed:
        return AppColors.success;
      case StageStatus.inProgress:
        return AppColors.orange;
      case StageStatus.upcoming:
        return AppColors.neutral;
    }
  }
}

class JourneyStage {
  final String title;
  final StageStatus status;
  const JourneyStage({required this.title, required this.status});
}

class JourneyTrackerScreen extends StatelessWidget {
  /// The student's REAL current stage key (StudentProfile.journeyStage from
  /// the backend, e.g. 'university-review') — pass this from real data.
  /// When null, the current account's progress is fetched from the server.
  final bool useServer;
  final String? currentStageKey;
  final String journeyPathLabel;

  const JourneyTrackerScreen(
      {super.key,
      this.currentStageKey,
      this.useServer = true,
      this.journeyPathLabel = 'رحلتك الدراسية'});

  List<JourneyStage> _buildStages() {
    final currentIndex =
        kJourneyStageOrder.indexWhere((s) => s['key'] == currentStageKey);
    final resolvedIndex = currentIndex < 0 ? 0 : currentIndex;

    return List.generate(kJourneyStageOrder.length, (i) {
      final status = i < resolvedIndex
          ? StageStatus.completed
          : i == resolvedIndex
              ? StageStatus.inProgress
              : StageStatus.upcoming;
      return JourneyStage(
          title: kJourneyStageOrder[i]['title']!, status: status);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (useServer) return const LiveJourneyScreen();
    final stages = _buildStages();
    final completedCount =
        stages.where((s) => s.status == StageStatus.completed).length;
    final progress = completedCount / stages.length;

    return AppScaffold(
      title: 'رحلتي',
      showBackButton: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.event_note_rounded, color: Colors.white),
          tooltip: 'المواعيد المهمة',
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ImportantDatesScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
          tooltip: 'التقويم',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.flight_land_rounded, color: Colors.white),
          tooltip: 'خدمات الوصول',
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArrivalServicesScreen())),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(journeyPathLabel, style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Text(
                          '${(progress * 100).round()}% مكتمل — $completedCount من ${stages.length} مرحلة',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: AnimatedProgressRing(
                    value: progress,
                    size: 46,
                    strokeWidth: 5,
                    centerBuilder: (animatedPercent) => Text(
                        '${(animatedPercent * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(stages.length, (i) {
            final stage = stages[i];
            final isLast = i == stages.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: stage.status == StageStatus.completed
                              ? AppColors.success
                              : Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: stage.status.color, width: 2),
                        ),
                        child: Center(
                          child: stage.status == StageStatus.completed
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                      color: stage.status.color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: AnimatedProgressLine(
                            value:
                                stage.status == StageStatus.completed ? 1 : 0,
                            color: AppColors.success,
                            backgroundColor: AppColors.border,
                            thickness: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22, top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(stage.title,
                                style: stage.status == StageStatus.inProgress
                                    ? AppTextStyles.cardTitle
                                        .copyWith(color: AppColors.orange)
                                    : AppTextStyles.cardTitle),
                          ),
                          StatusBadge(
                              label: stage.status.label,
                              color: stage.status.color),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class LiveJourneyScreen extends StatefulWidget {
  const LiveJourneyScreen({super.key});
  @override
  State<LiveJourneyScreen> createState() => _LiveJourneyScreenState();
}

class _LiveJourneyScreenState extends State<LiveJourneyScreen> {
  late Future<DashboardOverview> future =
      StudentRepository.instance.getOverview();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('journey_tracker');
  }

  void refresh() =>
      setState(() => future = StudentRepository.instance.getOverview());
  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardOverview>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const AppScaffold(title: 'رحلتي', body: LoadingState());
          if (snapshot.hasError)
            return AppScaffold(
                title: 'رحلتي',
                body:
                    ErrorState(message: 'تعذر تحميل رحلتك', onRetry: refresh));
          final overview = snapshot.data!;
          if (overview.journeys != null)
            return JourneyRequirementsView(
                journeys: overview.journeys!,
                onRefresh: () async {
                  refresh();
                  await future;
                });
          final stage = overview.journeyStage;
          if (stage == null || stage.isEmpty) {
            return AppScaffold(
                title: 'رحلتي',
                actions: [
                  IconButton(
                      onPressed: refresh, icon: const Icon(Icons.refresh))
                ],
                body: RefreshIndicator(
                    onRefresh: () async {
                      refresh();
                      await future;
                    },
                    color: AppColors.navy,
                    child: ListView(children: [
                      for (final item in overview.stages)
                        ListTile(
                            title: Text(item.titleAr),
                            subtitle: Text(item.descriptionAr),
                            leading: Icon(item.status == 'completed'
                                ? Icons.check_circle
                                : item.status == 'current'
                                    ? Icons.radio_button_checked
                                    : Icons.circle_outlined)),
                    ])));
          }
          return RefreshIndicator(
              onRefresh: () async {
                refresh();
                await future;
              },
              color: AppColors.navy,
              child: JourneyTrackerScreen(
                  currentStageKey: stage, useServer: false));
        },
      );
}
