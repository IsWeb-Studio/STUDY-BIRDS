import 'recognitions_carousel.dart';
import '../../core/widgets/cached_resource.dart';
import 'student_menu.dart';
export 'student_menu.dart' show showStudentMenu;
import '../services_support/community_screen.dart';
import '../../core/widgets/current_user_avatar.dart';
import '../stories/student_stories.dart';
import '../games/wink_screen.dart';
import '../ai/assistant_avatar.dart';
import 'home_journey_summary_card.dart';
import 'journey_preview_card.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/status_info.dart';
import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/animations.dart';
import '../../core/repositories/student_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/realtime_sync_service.dart';
import '../profile_account/profile_account_screens.dart';
import 'notifications_screen.dart';
import 'global_search_screen.dart';
import 'journey_tracker_screen.dart';
import 'activity_log_screen.dart';
import '../applications_documents_payments/applications_screens.dart';
import '../applications_documents_payments/documents_screens.dart';
import '../applications_documents_payments/payments_screens.dart';
import '../universities_programs_countries/universities_screens.dart';
import '../universities_programs_countries/countries_scholarships_screens.dart';
import '../services_support/services_consultation_screens.dart';
import '../services_support/support_team_ai_screens.dart';
import '../community/student_community_hub.dart';
import '../universities_programs_countries/programs_screens.dart';
import '../visa_travel_accommodation/accommodation_arrival_screens.dart';
import '../visa_travel_accommodation/visa_travel_screens.dart'
    show
        InsuranceScreen,
        EquivalencyScreen,
        VisaCenterScreen,
        TravelCenterScreen;
import 'smart_home_sections.dart';
import 'student_banner_carousel.dart';

/// Real, live Home Dashboard — fetches GET /api/students/overview on load.
class HomeDashboardScreen extends StatefulWidget {
  /// When true (used inside StudentAppShell), this screen has no Scaffold/
  /// bottom-nav of its own — the shell provides one shared bar instead.
  final bool embedInShell;
  final bool isActive;
  const HomeDashboardScreen(
      {super.key, this.embedInShell = false, this.isActive = true});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with CachedResource<HomeDashboardScreen> {
  @override
  Iterable<String> get cachedPaths => const ["/students/overview"];
  @override
  Future<void> reloadCachedResource() => _load();
  DashboardOverview? _overview;
  bool _loading = true;
  String? _error;
  StreamSubscription<DateTime>? _syncSub;
  bool _syncRefreshing = false;
  int _selectedJourneyIndex = 0;
  late final PageController _journeyPageController;

  // Quick-access items shown in the horizontal strip.
  static const List<Map<String, dynamic>> _quickActions = [
    {'label': 'طلباتي', 'icon': Icons.description_outlined},
    {'label': 'الجامعات', 'icon': Icons.account_balance_outlined},
    {'label': 'مستنداتي', 'icon': Icons.folder_open_outlined},
    {'label': 'المدفوعات', 'icon': Icons.payments_outlined},
    {'label': 'COVEY AI', 'icon': null},
    {'label': 'استشارة', 'icon': Icons.support_agent_outlined},
    {'label': 'الدعم', 'icon': Icons.headset_mic_outlined},
    {'label': 'المجتمع', 'icon': Icons.forum_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _journeyPageController = PageController(viewportFraction: .92);
    _load();
    AnalyticsService.instance.screenView('home_dashboard');
    _syncSub = RealtimeSyncService.instance.onTick.listen((_) {
      _refreshVisibleOverview();
    });
  }

  @override
  void dispose() {
    _journeyPageController.dispose();
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _overview == null;
      _error = null;
    });
    try {
      final overview = await StudentRepository.instance.getOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات الرئيسية — تحقق من الاتصال وحاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  Future<void> _refreshVisibleOverview() async {
    if (!mounted ||
        !widget.isActive ||
        _syncRefreshing ||
        _loading ||
        !(ModalRoute.isCurrentOf(context) ?? true) ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _syncRefreshing = true;
    try {
      final data =
          await StudentRepository.instance.getOverview(forceRefresh: true);
      if (mounted) setState(() => _overview = data);
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'home.overview.refresh');
    } finally {
      _syncRefreshing = false;
    }
  }

  void _openMenu(BuildContext context) => showStudentMenu(context);

  /// Opens a home destination key sent by the server (context card, dates,
  /// sections, quick actions).
  void _openDestination(String destination) {
    if (destination == 'consultation') {
      showAnimatedBottomSheet(context,
          builder: (_) => SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: const ConsultationBookingScreen(),
              ));
      return;
    }
    final Widget screen = switch (destination) {
      'journey' => const JourneyTrackerScreen(),
      'visa' => const VisaCenterScreen(),
      'travel' => const TravelCenterScreen(),
      'accommodation' => const AccommodationScreen(),
      'university-registration' => const UniversityRegistrationScreen(),
      'insurance' => const InsuranceScreen(),
      'equivalency' => const EquivalencyScreen(),
      'programs' || 'catalog' => const ProgramsExplorerScreen(),
      'universities' => const UniversitiesExplorerScreen(),
      'scholarships' => const ScholarshipsScreen(),
      'documents' || 'upload-document' => const MyDocumentsScreen(),
      'payments' => const PaymentsSummaryScreen(),
      'support' => const SupportCenterScreen(),
      'notifications' => const NotificationsScreen(),
      'bird-ai' => const BirdAIChatScreen(),
      'community' => const StudentCommunityHub(),
      _ => const ApplicationsListScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static const Map<String, IconData> _quickActionIcons = {
    'programs': Icons.menu_book_outlined,
    'universities': Icons.account_balance_outlined,
    'applications': Icons.description_outlined,
    'upload-document': Icons.upload_file_outlined,
    'consultation': Icons.support_agent_outlined,
    'visa': Icons.badge_outlined,
    'travel': Icons.flight_takeoff_outlined,
    'accommodation': Icons.home_work_outlined,
    'payments': Icons.payments_outlined,
    'support': Icons.headset_mic_outlined,
    'community': Icons.forum_outlined,
  };

  List<Map<String, dynamic>> _visibleQuickActions(Map<String, dynamic>? home) {
    final server = home?['quickActions'];
    List<Map<String, dynamic>> actions;
    if (server is! List || server.isEmpty) {
      actions = _quickActions
          .map((q) => {...q, 'destination': _legacyDestinations[q['label']]})
          .toList();
    } else {
      actions = [
        for (final item in server.whereType<Map>())
          {
            'label': '${item['labelAr'] ?? item['key']}',
            'icon': _quickActionIcons[item['key']],
            'destination': '${item['destination'] ?? item['key']}',
          },
        {
          'label': 'المجتمع',
          'icon': Icons.forum_outlined,
          'destination': 'community',
        },
      ];
    }
    return actions;
  }

  static const Map<String, String> _legacyDestinations = {
    'طلباتي': 'applications',
    'الجامعات': 'universities',
    'مستنداتي': 'documents',
    'المدفوعات': 'payments',
    'COVEY AI': 'bird-ai',
    'استشارة': 'consultation',
    'الدعم': 'support',
    'المجتمع': 'community',
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.navy,
            child: _loading
                ? const LoadingState(message: 'جاري تحميل رحلتك...')
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _buildContent(context, _overview!),
          ),
        ),
        bottomNavigationBar: widget.embedInShell
            ? null
            : BottomNavigationBar(
                currentIndex: 0,
                selectedItemColor: AppColors.greenInk,
                unselectedItemColor: AppColors.textSecondary,
                type: BottomNavigationBarType.fixed,
                onTap: (i) {
                  if (i == 1) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const StudentCommunityScreen()));
                  } else if (i == 2) {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WinkScreen()));
                  }
                },
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.forum_outlined), label: 'مجتمع الطلاب'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.sports_esports_outlined),
                      label: 'الغمّازة'),
                ],
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardOverview overview) {
    final currentStage = overview.stages.firstWhere(
      (s) => s.status == 'current',
      orElse: () => overview.stages.isNotEmpty
          ? overview.stages.last
          : const DashboardStage(
              key: '',
              titleAr: 'اختر برنامجك الدراسي',
              descriptionAr: 'استكشف الجامعات والبرامج وابدأ طلبك.',
              status: 'current'),
    );
    final completedCount =
        overview.stages.where((s) => s.status == 'completed').length;
    final home = overview.home;
    final homeStatus = home?['statusCard'] is Map
        ? Map<String, dynamic>.from(Json.rawMap(home!['statusCard']))
        : null;
    final progress = home?['progressPercent'] is num
        ? (home!['progressPercent'] as num).clamp(0, 100) / 100
        : overview.stages.isEmpty
            ? 0.0
            : completedCount / overview.stages.length;

    String journeyPathLabel = 'لم تبدأ رحلة تقديم بعد';
    final journey = home?['currentJourney'];
    if (journey is Map) {
      final parts = [journey['country'], journey['city'], journey['program']]
          .map((e) => '${e ?? ''}'.trim())
          .where((e) => e.isNotEmpty);
      if (parts.isNotEmpty) journeyPathLabel = parts.join(' - ');
    } else if (overview.recentApplications.isNotEmpty) {
      final app = Json.map(overview.recentApplications.first);
      final program = Json.mapOrNull(app['program']);
      final university = Json.mapOrNull(program?['university']);
      final uniName = university?['name'] as String?;
      final progName = program?['name'] as String?;
      if (uniName != null || progName != null) {
        journeyPathLabel =
            [uniName, progName].where((e) => e != null).join(' — ');
      }
    }

    final latestNotification = overview.latestNotification;
    final quickActions = _visibleQuickActions(home);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const CachedDataNotice(paths: ['/students/overview']),
        // ── Hero ──────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navy, AppColors.navy.withValues(alpha: 0.92)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'حسابي',
                    child: Tooltip(
                      message: 'حسابي',
                      child: InkWell(
                        key: const ValueKey('student-home-account'),
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
                        child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.green, width: 2)),
                            child: const CurrentUserAvatar(radius: 22)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _HeroIconButton(
                      key: const ValueKey('student-home-menu'),
                      icon: Icons.menu_rounded,
                      tooltip: 'القائمة',
                      onPressed: () => _openMenu(context)),
                  const SizedBox(width: 8),
                  _HeroIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'الإشعارات',
                    badgeCount: overview.stats.unreadNotifications,
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card)),
                child: TextField(
                  readOnly: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen())),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن جامعة، برنامج، دولة...',
                    hintStyle:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.navy, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),

        Container(
          key: const ValueKey('dashboard-stories'),
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          color: AppColors.navy,
          child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: StudentStories(
                  isActive: widget.isActive,
                  showCommunityButton: false,
                  compact: true)),
        ),
        const SizedBox(height: 16),
        // ── Journey card(s) ───────────────────────────────────────────────────
        _buildJourneySection(context, overview, currentStage, journeyPathLabel,
            progress, homeStatus),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: StudentBannerCarousel(onExplore: _openDestination),
        ),

        // ── Recognitions slider ───────────────────────────────────────────────
        if (overview.recognitions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('الشهادات والاعترافات',
                  style: AppTextStyles.sectionLabel),
            ),
          ),
          const SizedBox(height: 10),
          RecognitionsCarousel(recognitions: overview.recognitions),
        ],

        const SizedBox(height: 4),

        // ── Context card ──────────────────────────────────────────────────────
        if (home != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SmartHomeContextCard(home: home, onOpen: _openDestination),
          ),
          const SizedBox(height: 16),
        ],

        // ── Quick-access label ────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('الوصول السريع', style: AppTextStyles.sectionLabel),
          ),
        ),
        const SizedBox(height: 10),

        // ── Quick-access horizontal scroll ────────────────────────────────────
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: quickActions.length,
            itemBuilder: (context, i) {
              final q = quickActions[i];
              return Padding(
                padding:
                    EdgeInsets.only(left: i < quickActions.length - 1 ? 12 : 0),
                child: GestureDetector(
                  onTap: () => _openDestination('${q['destination']}'),
                  child: SizedBox(
                    width: 68,
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: q['destination'] == 'bird-ai'
                                ? const AssistantAvatar(size: 44)
                                : AppIconTile(q['icon'] as IconData? ??
                                    Icons.auto_awesome_rounded),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          q['label'] as String,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Dates + sections ──────────────────────────────────────────────────
        if (home != null) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SmartHomeDates(home: home, onOpen: _openDestination),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SmartHomeSections(home: home, onOpen: _openDestination),
          ),
        ],

        // ── Scholarships ──────────────────────────────────────────────────────
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('المنح الدراسية المتاحة',
                    style: AppTextStyles.sectionLabel),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ScholarshipsScreen())),
                child: const Text('عرض الكل',
                    style: TextStyle(
                        color: AppColors.greenInk,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ScholarshipsScreen())),
              child: const ListTile(
                  leading: Icon(Icons.school_outlined),
                  title: Text('استكشف المنح المنشورة'),
                  subtitle: Text('اطّلع على الشروط وقدّم طلبك وتابع حالته.'))),
        ),

        // ── Latest notification ───────────────────────────────────────────────
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('آخر إشعار', style: AppTextStyles.sectionLabel),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: latestNotification != null
              ? AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NotificationsScreen())),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined,
                          color: AppColors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              latestNotification['title'] as String? ?? '',
                              style: AppTextStyles.body)),
                    ],
                  ),
                )
              : AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ActivityLogScreen())),
                  child: const Text('لا يوجد إشعارات جديدة حتى الآن.',
                      style: AppTextStyles.caption),
                ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── Journey section: single card or multi-journey PageView ──────────────────

  Widget _buildJourneySection(
    BuildContext context,
    DashboardOverview overview,
    DashboardStage currentStage,
    String journeyPathLabel,
    double progress,
    Map<String, dynamic>? homeStatus,
  ) {
    var apps =
        overview.recentApplications.whereType<Map<String, dynamic>>().toList();

    // Reorder to match tracker screen (overview.journeys order)
    if (overview.journeys?.isNotEmpty == true) {
      final ordered = <Map<String, dynamic>>[];
      for (final j in overview.journeys!) {
        final jId = (Json.rawMap(j))['applicationId']?.toString();
        final match = apps.where((a) => a['_id']?.toString() == jId);
        if (match.isNotEmpty) ordered.add(match.first);
      }
      for (final a in apps) {
        if (!ordered.any((o) => o['_id']?.toString() == a['_id']?.toString())) {
          ordered.add(a);
        }
      }
      if (ordered.isNotEmpty) apps = ordered;
    }

    if (apps.length <= 1) {
      return Transform.translate(
        offset: Offset.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildMainJourneyCard(context, overview, currentStage,
              journeyPathLabel, progress, homeStatus),
        ),
      );
    }

    // Multiple journeys — horizontal PageView + dots indicator.
    return Transform.translate(
      offset: Offset.zero,
      child: Column(
        children: [
          SizedBox(
            height: JourneyPreviewCard.heightFor(context),
            child: PageView.builder(
              controller: _journeyPageController,
              itemCount: apps.length,
              onPageChanged: (i) => setState(() => _selectedJourneyIndex = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
                child: _buildCompactJourneyCard(
                  context,
                  overview,
                  i,
                  apps[i],
                  _labelFromApp(apps[i]),
                  _realProgressFromJourneys(
                      overview, apps[i]['_id'] as String?),
                  homeStatus,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              apps.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _selectedJourneyIndex == i ? 16.0 : 6.0,
                height: 6,
                decoration: BoxDecoration(
                  color: _selectedJourneyIndex == i
                      ? AppColors.green
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full detailed card — used only when there is a single journey.
  Widget _buildMainJourneyCard(
    BuildContext context,
    DashboardOverview overview,
    DashboardStage currentStage,
    String journeyPathLabel,
    double progress,
    Map<String, dynamic>? homeStatus,
  ) {
    final app = overview.recentApplications
        .whereType<Map<String, dynamic>>()
        .firstOrNull;
    if (app != null) {
      return SizedBox(
        height: JourneyPreviewCard.heightFor(context),
        child: _buildCompactJourneyCard(
            context,
            overview,
            0,
            app,
            _labelFromApp(app),
            _realProgressFromJourneys(overview, app['_id']?.toString()),
            homeStatus),
      );
    }
    final currentJourney = Json.mapOrNull(overview.home?['currentJourney']);
    final applicationId = currentJourney?['applicationId']?.toString() ??
        overview.journeys?.firstOrNull?['applicationId']?.toString();
    final hasJourney = overview.stats.currentApplications > 0 ||
        (applicationId != null && applicationId.isNotEmpty) ||
        (overview.journeys?.isNotEmpty ?? false);
    return HomeJourneySummaryCard(
      compact: true,
      path: journeyPathLabel,
      stepLabel: overview.nextAction?['waiting'] == true
          ? 'متابعة الفريق'
          : 'الخطوة القادمة',
      step:
          '${homeStatus?['nextStepAr'] ?? overview.nextAction?['titleAr'] ?? ''}',
      description: overview.nextAction?['descriptionAr'] as String? ??
          currentStage.descriptionAr,
      progress: progress,
      applications: overview.stats.currentApplications,
      documents: overview.stats.acceptedDocuments,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => hasJourney
              ? JourneyTrackerScreen(
                  applicationId: applicationId,
                  currentStageKey: overview.journeyStage,
                  journeyPathLabel: journeyPathLabel)
              : const ProgramsExplorerScreen())),
    );
  }

  /// Unified journey card used in the multi-journey PageView.
  /// Same layout for every journey — only the data values differ.
  Widget _buildCompactJourneyCard(
    BuildContext context,
    DashboardOverview overview,
    int index,
    Map<String, dynamic> app,
    String label,
    double progress,
    Map<String, dynamic>? homeStatus,
  ) {
    final status = app['status'] as String? ?? 'submitted';
    final ringValue = progress;
    final bottomText = StatusInfo.of(app)?.label ?? _appStatusLabel(status);

    void openDetail() {
      final appId = app['_id'] as String?;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JourneyTrackerScreen(applicationId: appId),
      ));
    }

    final program = Json.mapOrNull(app['program']) ?? {};
    final university = Json.mapOrNull(program['university']) ?? {};
    final country = Json.mapOrNull(university['country']) ?? {};
    final journey = overview.journeys
        ?.where((j) => j['applicationId']?.toString() == app['_id']?.toString())
        .firstOrNull;
    final stages = (Json.listOrNull(journey?['stages']) ?? [])
        .whereType<Map>()
        .where((stage) => stage['status'] != 'not-required')
        .toList();
    final completed =
        stages.where((stage) => stage['status'] == 'completed').length;
    final current =
        stages.where((stage) => stage['status'] != 'completed').firstOrNull;
    final campus = Json.listOrNull(university['campusImages']) ?? [];
    final rawImage =
        country['heroImage'] ?? campus.firstOrNull ?? program['coverImage'];
    final uri = rawImage is String && rawImage.trim().isNotEmpty
        ? Uri.tryParse(rawImage.trim())
        : null;
    final image = uri == null
        ? null
        : Uri.parse(ApiClient.baseUrl)
            .replace(path: '/', query: null, fragment: null)
            .resolveUri(uri);
    return JourneyPreviewCard(
      title: '${program['title'] ?? program['name'] ?? label}',
      university: '${university['name'] ?? ''}',
      location: [country['nameAr'] ?? country['name'], university['city']]
          .where((v) => v != null && '$v'.trim().isNotEmpty)
          .join(' · '),
      status: bottomText,
      imageUrl: image != null && ['https', 'http'].contains(image.scheme)
          ? image.toString()
          : null,
      countryCode: country['code']?.toString(),
      currentStage: journey?['closed'] == true
          ? 'انتهت الرحلة'
          : current?['titleAr']?.toString() ??
              (stages.isNotEmpty ? 'اكتملت الرحلة' : bottomText),
      completedStages: completed,
      totalStages: stages.length,
      number: index + 1,
      total: overview.recentApplications.length,
      progress: ringValue,
      onTap: openDetail,
    );
  }

  String _labelFromApp(Map<String, dynamic> app) {
    final program = Json.mapOrNull(app['program']);
    final university = Json.mapOrNull(program?['university']);
    final parts = <String>[
      if (university?['name'] is String) university!['name'] as String,
      if (program?['name'] is String) program!['name'] as String,
    ];
    return parts.isNotEmpty ? parts.join(' — ') : 'طلب دراسي';
  }

  double _realProgressFromJourneys(DashboardOverview overview, String? appId) {
    if (appId == null || overview.journeys == null) return 0.0;
    final matches = overview.journeys!
        .whereType<Map<String, dynamic>>()
        .where((j) => j['applicationId']?.toString() == appId)
        .toList();
    if (matches.isEmpty) return 0.0;
    final journey = matches.first;
    final stages =
        (Json.listOrNull(journey['stages']) ?? []).whereType<Map>().toList();
    final active = stages.where((s) => s['status'] != 'not-required').toList();
    if (active.isEmpty) return 0.0;
    final done = active.where((s) => s['status'] == 'completed').length;
    return done / active.length;
  }

  String _appStatusLabel(String status) => switch (status) {
        'submitted' => 'قيد الانتظار',
        'under-review' ||
        'under_review' ||
        'in_review' ||
        'reviewing' =>
          'قيد المراجعة',
        'accepted' || 'approved' => 'مقبول',
        'rejected' => 'مرفوض',
        'pending' || 'pending_docs' => 'معلّق',
        _ => status,
      };
}

/// Soft frosted circular icon button used in the hero.
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final String? tooltip;
  const _HeroIconButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      this.badgeCount = 0,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon, color: Colors.white, size: 20)),
        ),
        if (hasBadge)
          Positioned(
            right: 4,
            top: 4,
            child: badgeCount > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                : Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: AppColors.greenInk, shape: BoxShape.circle)),
          ),
      ],
    );
  }
}
