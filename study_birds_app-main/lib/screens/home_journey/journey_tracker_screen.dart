import 'journey_requirements_view.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import 'journey_timeline_widgets.dart';
import '../../core/repositories/student_repository.dart';
import '../../core/services/analytics_service.dart';
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
  /// When set, only the journey matching this application ID is shown.
  final String? applicationId;

  const JourneyTrackerScreen(
      {super.key,
      this.currentStageKey,
      this.useServer = true,
      this.applicationId,
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
    if (useServer) return LiveJourneyScreen(applicationId: applicationId);
    final stages = _buildStages();
    final completed =
        stages.where((stage) => stage.status == StageStatus.completed).length;
    return AppScaffold(
      title: 'رحلتي',
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
      body: ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            JourneySummaryCard(
                title: journeyPathLabel,
                completed: completed,
                total: stages.length),
            const SizedBox(height: 22),
            for (var i = 0; i < stages.length; i++)
              JourneyTimelineTile(
                number: i + 1,
                title: stages[i].title,
                statusLabel: stages[i].status.label,
                completed: stages[i].status == StageStatus.completed,
                current: stages[i].status == StageStatus.inProgress,
                last: i == stages.length - 1,
              ),
          ]),
    );
  }
}

class LiveJourneyScreen extends StatefulWidget {
  /// When set, only the journey matching this application ID is shown.
  final String? applicationId;
  const LiveJourneyScreen({super.key, this.applicationId});
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
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppScaffold(title: 'رحلتي', body: LoadingState());
          }
          if (snapshot.hasError) {
            return AppScaffold(
                title: 'رحلتي',
                body:
                    ErrorState(message: 'تعذر تحميل رحلتك', onRetry: refresh));
          }
          final overview = snapshot.data!;
          if (overview.journeys != null) {
            var journeys = overview.journeys!;
            final filterId = widget.applicationId;
            if (filterId != null) {
              final filtered = journeys
                  .where((j) => j['applicationId']?.toString() == filterId)
                  .toList();
              if (filtered.isNotEmpty) journeys = filtered;
            }
            return JourneyRequirementsView(
                journeys: journeys,
                onRefresh: () async {
                  refresh();
                  await future;
                });
          }
          final stage = overview.journeyStage;
          if (stage == null || stage.isEmpty) {
            return JourneyRequirementsView(
              onRefresh: () async {
                refresh();
                await future;
              },
              journeys: overview.stages.isEmpty
                  ? []
                  : [
                      {
                        'title': 'رحلتك الدراسية',
                        'stages': [
                          for (final item in overview.stages)
                            {
                              'titleAr': item.titleAr,
                              'descriptionAr': item.descriptionAr,
                              'status': item.status == 'current'
                                  ? 'in-progress'
                                  : item.status == 'upcoming'
                                      ? 'not-started'
                                      : item.status,
                            }
                        ],
                      }
                    ],
            );
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
