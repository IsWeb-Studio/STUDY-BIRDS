import 'dart:async';
import '../../core/services/realtime_sync_service.dart';
import '../../core/services/error_reporter.dart';
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
  final bool isActive;
  final String? currentStageKey;
  final String journeyPathLabel;
  /// When set, only the journey matching this application ID is shown.
  final String? applicationId;

  const JourneyTrackerScreen(
      {super.key,
      this.currentStageKey,
      this.useServer = true,
      this.isActive = true,
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
    if (useServer) return LiveJourneyScreen(applicationId: applicationId, isActive: isActive);
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
  final bool isActive;
  const LiveJourneyScreen({super.key, this.applicationId, this.isActive = true});
  @override
  State<LiveJourneyScreen> createState() => _LiveJourneyScreenState();
}

class _LiveJourneyScreenState extends State<LiveJourneyScreen> with WidgetsBindingObserver {
  StreamSubscription<DateTime>? _syncSub;
  DashboardOverview? _overview;
  Object? _error;
  Future<void>? _refreshing;
  bool _visible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    AnalyticsService.instance.screenView('journey_tracker');
    _syncSub = RealtimeSyncService.instance.onTick.listen((_) => refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateVisibility();
  }

  @override
  void didUpdateWidget(covariant LiveJourneyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateVisibility();
  }

  void _updateVisibility() {
    final visible = widget.isActive && _foreground &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final becameVisible = visible && !_visible;
    _visible = visible;
    if (becameVisible) unawaited(refresh());
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh() {
    if (!mounted || !_visible) return Future.value();
    return _refreshing ??= _load().whenComplete(() => _refreshing = null);
  }

  Future<void> _load() async {
    try {
      final overview = await StudentRepository.instance.getOverview(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _error = null;
      });
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'journey.refresh');
      if (mounted) setState(() => _error = error);
    }
  }
  @override
  Widget build(BuildContext context) {
          if (_overview == null && _error == null) {
            return const AppScaffold(title: 'رحلتي', body: LoadingState());
          }
          if (_overview == null && _error != null) {
            return AppScaffold(
                title: 'رحلتي',
                body:
                    ErrorState(message: 'تعذر تحميل رحلتك', onRetry: refresh));
          }
          final overview = _overview!;
          if (overview.journeys != null) {
            var journeys = overview.journeys!;
            final filterId = widget.applicationId;
            if (filterId != null) {
              final filtered = journeys
                  .where((j) => j['applicationId']?.toString() == filterId)
                  .toList();
              journeys = filtered;
            }
            return JourneyRequirementsView(
                journeys: journeys,
                applications: overview.recentApplications.whereType<Map<String, dynamic>>().toList(),
                detailBuilder: (journey) => LiveJourneyScreen(
                    applicationId: journey['applicationId']?.toString()),
                onRefresh: () async {
                  await refresh();
                });
          }
          final stage = overview.journeyStage;
          if (stage == null || stage.isEmpty) {
            return JourneyRequirementsView(
              onRefresh: () async {
                await refresh();
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
                await refresh();
              },
              color: AppColors.navy,
              child: JourneyTrackerScreen(
                  currentStageKey: stage, useServer: false));
  }
}
