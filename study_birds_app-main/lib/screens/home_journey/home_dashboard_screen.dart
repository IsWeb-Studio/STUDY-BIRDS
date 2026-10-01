import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/animations.dart';
import '../../core/student_repository.dart';
import '../../core/auth_session.dart';
import '../../core/analytics_service.dart';
import '../../core/realtime_sync_service.dart';
import '../../main.dart' show RootChooserScreen;
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
import '../services_support/community_screen.dart';
import '../universities_programs_countries/programs_screens.dart';
import '../universities_programs_countries/explore_hub_screen.dart';
import '../visa_travel_accommodation/accommodation_arrival_screens.dart';
import '../visa_travel_accommodation/visa_travel_screens.dart' show InsuranceScreen, EquivalencyScreen, VisaCenterScreen, TravelCenterScreen;
import 'smart_home_sections.dart';

/// Real, live Home Dashboard — fetches GET /api/students/overview on load.
class HomeDashboardScreen extends StatefulWidget {
  /// When true (used inside StudentAppShell), this screen has no Scaffold/
  /// bottom-nav of its own — the shell provides one shared bar instead.
  final bool embedInShell;
  const HomeDashboardScreen({super.key, this.embedInShell = false});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  DashboardOverview? _overview;
  bool _loading = true;
  String? _error;
  StreamSubscription<DateTime>? _syncSub;
  int _selectedJourneyIndex = 0;
  late final PageController _journeyPageController;

  // Quick-access items shown in the horizontal strip.
  static const List<Map<String, dynamic>> _quickActions = [
    {'label': 'طلباتي',   'icon': Icons.description_outlined},
    {'label': 'الجامعات', 'icon': Icons.account_balance_outlined},
    {'label': 'مستنداتي', 'icon': Icons.folder_open_outlined},
    {'label': 'المدفوعات', 'icon': Icons.payments_outlined},
    {'label': 'Bird AI',   'icon': null},
    {'label': 'استشارة',  'icon': Icons.support_agent_outlined},
    {'label': 'الدعم',    'icon': Icons.headset_mic_outlined},
    {'label': 'المجتمع',  'icon': Icons.forum_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _journeyPageController = PageController();
    _load();
    AnalyticsService.instance.screenView('home_dashboard');
    _syncSub = RealtimeSyncService.instance.onTick.listen((_) {
      StudentRepository.instance
          .getOverview(forceRefresh: true)
          .then((data) { if (mounted) setState(() => _overview = data); })
          .catchError((_) {});
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
      _loading = true;
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

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        void go(Widget screen) {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
        }

        Widget row(IconData icon, String label, VoidCallback onTap,
            {bool danger = false}) {
          final color = danger ? AppColors.danger : AppColors.orange;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: danger
                                  ? AppColors.danger
                                  : AppColors.textPrimary)),
                      const Spacer(),
                      Icon(Icons.arrow_back_ios_new_rounded,
                          size: 13,
                          color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        row(Icons.description_outlined,     'طلباتي',     () => go(const ApplicationsListScreen())),
                        row(Icons.account_balance_outlined, 'الجامعات',   () => go(const UniversitiesExplorerScreen())),
                        row(Icons.menu_book_outlined,       'البرامج',    () => go(const ProgramsExplorerScreen())),
                        row(Icons.school_outlined,          'المنح',      () => go(const ScholarshipsScreen())),
                        row(Icons.person_outline_rounded,   'حسابي',      () => go(const ProfileScreen())),
                        row(Icons.notifications_outlined,   'الإشعارات',  () => go(const NotificationsScreen())),
                        row(Icons.headset_mic_outlined,     'مركز الدعم', () => go(const SupportCenterScreen())),
                        row(Icons.forum_outlined,           'المجتمع',    () => go(const StudentCommunityScreen())),
                        const Divider(height: 20),
                        row(Icons.logout_rounded, 'تسجيل الخروج', () async {
                          Navigator.pop(sheetContext);
                          final confirmed = await showAppConfirmDialog(
                            context,
                            title: 'تسجيل الخروج',
                            message: 'هل تريد تسجيل الخروج من حسابك؟',
                            confirmLabel: 'تسجيل الخروج',
                            danger: true,
                          );
                          if (!confirmed || !context.mounted) return;
                          await AuthSession.instance.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const RootChooserScreen()),
                                (route) => false);
                          }
                        }, danger: true),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens a home destination key sent by the server (context card, dates,
  /// sections, quick actions).
  void _openDestination(String destination) {
    if (destination == 'consultation') {
      showAnimatedBottomSheet(context,
          builder: (_) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.88,
                child: const ConsultationBookingScreen(),
              ));
      return;
    }
    final Widget screen = switch (destination) {
      'journey'                  => const JourneyTrackerScreen(),
      'visa'                     => const VisaCenterScreen(),
      'travel'                   => const TravelCenterScreen(),
      'accommodation'            => const AccommodationScreen(),
      'university-registration'  => const UniversityRegistrationScreen(),
      'insurance'                => const InsuranceScreen(),
      'equivalency'              => const EquivalencyScreen(),
      'programs' || 'catalog'    => const ProgramsExplorerScreen(),
      'universities'             => const UniversitiesExplorerScreen(),
      'documents' || 'upload-document' => const MyDocumentsScreen(),
      'payments'                 => const PaymentsSummaryScreen(),
      'support'                  => const SupportCenterScreen(),
      'notifications'            => const NotificationsScreen(),
      'bird-ai'                  => const BirdAIChatScreen(),
      'community'                => const StudentCommunityScreen(),
      _                          => const ApplicationsListScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static const Map<String, IconData> _quickActionIcons = {
    'programs':       Icons.menu_book_outlined,
    'universities':   Icons.account_balance_outlined,
    'applications':   Icons.description_outlined,
    'upload-document': Icons.upload_file_outlined,
    'consultation':   Icons.support_agent_outlined,
    'visa':           Icons.badge_outlined,
    'travel':         Icons.flight_takeoff_outlined,
    'accommodation':  Icons.home_work_outlined,
    'payments':       Icons.payments_outlined,
    'support':        Icons.headset_mic_outlined,
    'community':      Icons.forum_outlined,
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
            'label':       '${item['labelAr'] ?? item['key']}',
            'icon':        _quickActionIcons[item['key']],
            'destination': '${item['destination'] ?? item['key']}',
          },
        {
          'label':       'المجتمع',
          'icon':        Icons.forum_outlined,
          'destination': 'community',
        },
      ];
    }
    return actions;
  }

  static const Map<String, String> _legacyDestinations = {
    'طلباتي':   'applications',
    'الجامعات': 'universities',
    'مستنداتي': 'documents',
    'المدفوعات': 'payments',
    'Bird AI':   'bird-ai',
    'استشارة':  'consultation',
    'الدعم':    'support',
    'المجتمع':  'community',
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
                selectedItemColor: AppColors.navy,
                unselectedItemColor: AppColors.textSecondary,
                type: BottomNavigationBarType.fixed,
                onTap: (i) {
                  switch (i) {
                    case 1:
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const JourneyTrackerScreen()));
                    case 2:
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ExploreHubScreen()));
                    case 3:
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ServicesCenterScreen()));
                    case 4:
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ProfileScreen()));
                  }
                },
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.timeline_rounded), label: 'الرحلة'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.explore_outlined), label: 'استكشاف'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.miscellaneous_services_outlined),
                      label: 'الخدمات'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
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
              titleAr: 'رحلتك الدراسية',
              descriptionAr: 'مرحبًا بك في Study Birds',
              status: 'current'),
    );
    final completedCount =
        overview.stages.where((s) => s.status == 'completed').length;
    final home = overview.home;
    final homeStatus = home?['statusCard'] is Map
        ? Map<String, dynamic>.from(home!['statusCard'] as Map)
        : null;
    final progress = home?['progressPercent'] is num
        ? (home!['progressPercent'] as num).clamp(0, 100) / 100
        : overview.stages.isEmpty
            ? 0.0
            : completedCount / overview.stages.length;
    final greetingName = home?['greeting'] is Map
        ? '${(home!['greeting'] as Map)['name'] ?? ''}'.trim()
        : '';

    String journeyPathLabel = 'لم تبدأ رحلة تقديم بعد';
    final journey = home?['currentJourney'];
    if (journey is Map) {
      final parts = [journey['country'], journey['city'], journey['program']]
          .map((e) => '${e ?? ''}'.trim())
          .where((e) => e.isNotEmpty);
      if (parts.isNotEmpty) journeyPathLabel = parts.join(' - ');
    } else if (overview.recentApplications.isNotEmpty) {
      final app = overview.recentApplications.first as Map<String, dynamic>;
      final program = app['program'] as Map<String, dynamic>?;
      final university = program?['university'] as Map<String, dynamic>?;
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
        // ── Hero ──────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navy, AppColors.navy.withValues(alpha: 0.92)],
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _HeroIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: 'القائمة',
                      onPressed: () => _openMenu(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                            greetingName.isEmpty
                                ? 'مرحباً بك'
                                : 'مرحباً $greetingName',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2)),
                        const SizedBox(height: 2),
                        Text(
                            '${homeStatus?['labelAr'] ?? ''}'.isNotEmpty
                                ? '${homeStatus!['labelAr']}'
                                : currentStage.titleAr,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
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

        // ── Journey card(s) ───────────────────────────────────────────────────
        _buildJourneySection(
            context, overview, currentStage, journeyPathLabel, progress, homeStatus),

        // ── Recognitions slider ───────────────────────────────────────────────
        if (overview.recognitions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('الشهادات والاعترافات', style: AppTextStyles.sectionLabel),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: overview.recognitions.length,
              itemBuilder: (context, i) {
                final rec = overview.recognitions[i];
                final image = rec['image'] as String? ?? '';
                final title = rec['title'] as String? ?? '';
                final link = rec['link'] as String? ?? '';
                final card = Container(
                  margin: EdgeInsets.only(left: i < overview.recognitions.length - 1 ? 10 : 0),
                  width: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (image.isNotEmpty)
                        Expanded(
                          child: AppNetworkImage(
                            image,
                            fit: BoxFit.contain,
                            errorWidget: const Icon(
                              Icons.verified_outlined,
                              color: AppColors.orange,
                              size: 24,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.verified_outlined, color: AppColors.orange, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
                if (link.isEmpty) return card;
                return GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(link);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: card,
                );
              },
            ),
          ),
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
                            child: AppIconTile(q['icon'] as IconData? ??
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
                        color: AppColors.orange,
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
                  subtitle:
                      Text('اطّلع على الشروط وقدّم طلبك وتابع حالته.'))),
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
                          color: AppColors.orange, size: 18),
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
    var apps = overview.recentApplications
        .whereType<Map<String, dynamic>>()
        .toList();

    // Reorder to match tracker screen (overview.journeys order)
    if (overview.journeys?.isNotEmpty == true) {
      final ordered = <Map<String, dynamic>>[];
      for (final j in overview.journeys!) {
        final jId = (j as Map)['applicationId']?.toString();
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
        offset: const Offset(0, -20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildMainJourneyCard(
              context, overview, currentStage, journeyPathLabel, progress, homeStatus),
        ),
      );
    }

    // Multiple journeys — horizontal PageView + dots indicator.
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Column(
        children: [
          SizedBox(
            height: 248,
            child: PageView.builder(
              controller: _journeyPageController,
              itemCount: apps.length,
              onPageChanged: (i) =>
                  setState(() => _selectedJourneyIndex = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCompactJourneyCard(
                  context,
                  overview,
                  i,
                  apps[i],
                  _labelFromApp(apps[i]),
                  _realProgressFromJourneys(overview, apps[i]['_id'] as String?),
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
                      ? AppColors.navy
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
    return AppCard(
      margin: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JourneyTrackerScreen(
            currentStageKey: overview.journeyStage,
            journeyPathLabel: journeyPathLabel),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رحلتك الحالية',
                        style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 4),
                    Text(journeyPathLabel, style: AppTextStyles.body),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                height: 44,
                child: AnimatedProgressRing(
                  value: progress,
                  size: 44,
                  strokeWidth: 4,
                  centerBuilder: (v) => Text('${(v * 100).round()}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          color: AppColors.navy)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              children: [
                Container(
                    width: 3,
                    decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          overview.nextAction?['waiting'] == true
                              ? 'متابعة الفريق'
                              : 'الخطوة القادمة',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      if ('${homeStatus?['nextStepAr'] ?? ''}'.isNotEmpty)
                        Text('${homeStatus!['nextStepAr']}',
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                      Text(
                          overview.nextAction?['descriptionAr'] as String? ??
                              currentStage.descriptionAr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  label: overview.nextAction == null
                      ? 'تفاصيل الرحلة'
                      : 'عرض التفاصيل',
                  expand: false,
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => JourneyTrackerScreen(
                            currentStageKey: overview.journeyStage,
                            journeyPathLabel: journeyPathLabel)));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineStat(
                  icon: Icons.description_outlined,
                  value: '${overview.stats.currentApplications}',
                  label: 'الطلبات النشطة',
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _InlineStat(
                  icon: Icons.verified_outlined,
                  value: '${overview.stats.acceptedDocuments}',
                  label: 'مستندات مقبولة',
                ),
              ),
            ],
          ),
        ],
      ),
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
    final bottomText = _appStatusLabel(status);

    void openDetail() {
      final appId = app['_id'] as String?;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JourneyTrackerScreen(applicationId: appId),
      ));
    }

    return AppCard(
      margin: EdgeInsets.zero,
      onTap: openDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رحلة دراسية',
                        style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 4),
                    Text(label,
                        style:
                            AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                height: 44,
                child: AnimatedProgressRing(
                  value: ringValue,
                  size: 44,
                  strokeWidth: 4,
                  centerBuilder: (v) => Text(
                    '${(v * 100).round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        color: AppColors.navy),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  bottomText,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                label: 'تفاصيل الرحلة',
                expand: false,
                onPressed: openDetail,
              ),
            ],
          ),
        ],
      ),
    );
  }

String _labelFromApp(Map<String, dynamic> app) {
    final program = app['program'] as Map<String, dynamic>?;
    final university = program?['university'] as Map<String, dynamic>?;
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
    final stages = (journey['stages'] as List? ?? []).whereType<Map>().toList();
    final active = stages.where((s) => s['status'] != 'not-required').toList();
    if (active.isEmpty) return 0.0;
    final done = active.where((s) => s['status'] == 'completed').length;
    return done / active.length;
  }

  String _appStatusLabel(String status) => switch (status) {
        'submitted'                           => 'مُقدَّم',
        'under_review' || 'in_review' || 'reviewing' => 'قيد المراجعة',
        'accepted' || 'approved'              => 'مقبول',
        'rejected'                            => 'مرفوض',
        'pending' || 'pending_docs'           => 'معلّق',
        _                                     => status,
      };
}

/// Soft frosted circular icon button used in the hero.
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final String? tooltip;
  const _HeroIconButton(
      {required this.icon,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                : Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: AppColors.orange, shape: BoxShape.circle)),
          ),
      ],
    );
  }
}


/// Calm inline stat — icon, value, label, no border/box around it.
class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _InlineStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(value, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                style: AppTextStyles.caption, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
