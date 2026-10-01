import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import 'community_screen.dart' show StudentCommunityScreen;
import 'alumni_directory_screen.dart';
import 'student_listings_screen.dart';

// ─── shared helpers ───────────────────────────────────────────────────────────

String _fmtDate(dynamic raw) {
  final d = DateTime.tryParse('$raw')?.toLocal();
  if (d == null) return '';
  return '${d.day}/${d.month}/${d.year}';
}

// ─── بند 56: عروض ونمط الحياة الطلابية ────────────────────────────────────────

class StudentLifeOffersScreen extends StatefulWidget {
  const StudentLifeOffersScreen({super.key});
  @override
  State<StudentLifeOffersScreen> createState() =>
      _StudentLifeOffersScreenState();
}

class _StudentLifeOffersScreenState extends State<StudentLifeOffersScreen> {
  Map<String, dynamic>? _upcoming;
  List<dynamic> _past = [];
  bool _loading = true;
  String? _error;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/content/upcoming-event'),
        ApiClient.instance.get('/content/past-events'),
      ]);
      if (!mounted) return;
      setState(() {
        _upcoming = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        _past = results[1] is List ? results[1] as List : [];
      });
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = 'تعذر تحميل الفعاليات. تحقق من الاتصال وأعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final user = AuthSession.instance.currentUser;
    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';
    final yes = await showAppConfirmDialog(context,
        title: 'تسجيل الحضور',
        message: 'سيتم تسجيل اسمك "$userName" للفعالية القادمة. تأكيد؟',
        confirmLabel: 'تسجيل');
    if (yes != true || !mounted) return;
    setState(() => _registering = true);
    try {
      await ApiClient.instance.post('/content/event-registrations',
          body: {'name': userName, 'email': userEmail});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل حضورك بنجاح ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                e is ApiException ? e.message : 'تعذر التسجيل. حاول مجددًا.')));
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'الحياة الطلابية والفعاليات',
        actions: [TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const StudentListingsScreen(kind: 'offer'))), child: const Text('عروض الطلاب'))],
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.navy,
          child: _loading
              ? const LoadingState(message: 'جاري تحميل الفعاليات...')
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      children: [
                        const Text(
                            'اكتشف الفعاليات الطلابية والأنشطة المتاحة لك.',
                            style: AppTextStyles.body),
                        const SizedBox(height: 20),
                        if (_upcoming != null &&
                            (_upcoming!['title'] as String? ?? '').isNotEmpty)
                          _UpcomingEventCard(
                              event: _upcoming!,
                              registering: _registering,
                              onRegister: _register),
                        if (_upcoming == null ||
                            (_upcoming!['title'] as String? ?? '').isEmpty)
                          const AppCard(
                            child: Center(
                                child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('لا توجد فعالية قادمة حالياً.',
                                  style: AppTextStyles.caption),
                            )),
                          ),
                        const SizedBox(height: 20),
                        if (_past.isNotEmpty) ...[
                          const Text('الفعاليات السابقة',
                              style: AppTextStyles.sectionLabel),
                          const SizedBox(height: 10),
                          for (final e in _past)
                            if (e is Map)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PastEventCard(event: e),
                              ),
                        ],
                        const SizedBox(height: 20),
                        AppCard(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const StudentCommunityScreen())),
                          child: const Row(children: [
                            Icon(Icons.forum_rounded, color: AppColors.navy),
                            SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('مجتمع الطلاب',
                                      style: AppTextStyles.cardTitle),
                                  Text(
                                      'تبادل التجارب والنصائح مع زملائك الطلاب',
                                      style: AppTextStyles.caption),
                                ])),
                            Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: AppColors.textSecondary),
                          ]),
                        ),
                      ],
                    ),
        ),
      );
}

class _UpcomingEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool registering;
  final VoidCallback onRegister;
  const _UpcomingEventCard(
      {required this.event,
      required this.registering,
      required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final coverUrl = event['coverImage'] as String?;
    final date = _fmtDate(event['date']);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (coverUrl != null && coverUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppNetworkImage(coverUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorWidget: const SizedBox.shrink()),
          ),
        if (coverUrl != null && coverUrl.isNotEmpty) const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6)),
          child: const Text('الفعالية القادمة',
              style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        Text('${event['title'] ?? ''}', style: AppTextStyles.cardTitle),
        if ((event['description'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${event['description']}', style: AppTextStyles.body),
        ],
        if (date.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(date, style: AppTextStyles.caption),
          ]),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: registering ? 'جارٍ التسجيل...' : 'سجّل حضورك',
          onPressed: registering ? null : onRegister,
        ),
      ]),
    );
  }
}

class _PastEventCard extends StatelessWidget {
  final Map event;
  const _PastEventCard({required this.event});
  @override
  Widget build(BuildContext context) {
    final coverUrl = event['coverImage'] as String?;
    final date = _fmtDate(event['date']);
    return AppCard(
      child: Row(children: [
        if (coverUrl != null && coverUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppNetworkImage(coverUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: _iconBox()),
          )
        else
          _iconBox(),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${event['title'] ?? ''}', style: AppTextStyles.cardTitle),
          if (date.isNotEmpty)
            Text(date, style: AppTextStyles.caption),
        ])),
      ]),
    );
  }

  Widget _iconBox() => Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child:
          const Icon(Icons.event_rounded, color: AppColors.navy, size: 24));
}

// ─── بند 57: شبكة الخريجين ─────────────────────────────────────────────────────

class AlumniNetworkScreen extends StatefulWidget {
  const AlumniNetworkScreen({super.key});
  @override
  State<AlumniNetworkScreen> createState() => _AlumniNetworkScreenState();
}

class _AlumniNetworkScreenState extends State<AlumniNetworkScreen> {
  Map<String, dynamic>? _upcoming;
  List<dynamic> _past = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/content/upcoming-event'),
        ApiClient.instance.get('/content/past-events'),
      ]);
      if (!mounted) return;
      setState(() {
        _upcoming = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        _past = results[1] is List ? results[1] as List : [];
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر التحميل. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'شبكة الخريجين',
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.navy,
          child: _loading
              ? const LoadingState(message: 'جاري التحميل...')
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      children: [
                        AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: AppColors.navy.withValues(alpha: 0.08),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.workspace_premium_rounded,
                                    color: AppColors.navy, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Text('برنامج السفراء',
                                      style: AppTextStyles.cardTitle)),
                            ]),
                            const SizedBox(height: 10),
                            const Text(
                                'انضم لبرنامج سفراء Study Birds بعد تخرجك وساعد الطلاب الجدد في رحلتهم الدراسية.',
                                style: AppTextStyles.body),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ..._alumniCards(context),
                        if (_upcoming != null &&
                            (_upcoming!['title'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('الفعالية القادمة',
                              style: AppTextStyles.sectionLabel),
                          const SizedBox(height: 10),
                          AppCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${_upcoming!['title']}',
                                    style: AppTextStyles.cardTitle),
                                if ((_upcoming!['description'] as String? ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('${_upcoming!['description']}',
                                      style: AppTextStyles.body),
                                ],
                                if (_fmtDate(_upcoming!['date']).isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(_fmtDate(_upcoming!['date']),
                                      style: AppTextStyles.caption),
                                ],
                              ])),
                        ],
                        if (_past.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('فعاليات الخريجين السابقة',
                              style: AppTextStyles.sectionLabel),
                          const SizedBox(height: 10),
                          for (final e in _past)
                            if (e is Map)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AppCard(
                                      child: Row(children: [
                                    const Icon(Icons.event_rounded,
                                        color: AppColors.navy, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text('${e['title'] ?? ''}',
                                              style: AppTextStyles.cardTitle),
                                          if (_fmtDate(e['date']).isNotEmpty)
                                            Text(_fmtDate(e['date']),
                                                style: AppTextStyles.caption),
                                        ])),
                                  ]))),
                        ],
                        const SizedBox(height: 20),
                        AppCard(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const StudentCommunityScreen())),
                          child: const Row(children: [
                            Icon(Icons.forum_rounded, color: AppColors.navy),
                            SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('مجتمع الخريجين',
                                      style: AppTextStyles.cardTitle),
                                  Text('تواصل مع الخريجين وشارك تجربتك',
                                      style: AppTextStyles.caption),
                                ])),
                            Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: AppColors.textSecondary),
                          ]),
                        ),
                      ],
                    ),
        ),
      );

  List<Widget> _alumniCards(BuildContext context) => [
        _TappableInfoCard(
          icon: Icons.people_outline,
          title: 'دليل الخريجين وملفي',
          body: 'تعرّف على الخريجين المتاحين للإرشاد وأدر ظهور ملفك.',
          onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const AlumniDirectoryScreen())),
        ),
        const SizedBox(height: 12),
        _TappableInfoCard(
          icon: Icons.work_outline_rounded,
          title: 'وظائف وتدريب الخريجين',
          body: 'فرص نشرها خريجو Study Birds — تقديم مباشر.',
          onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const JobPostsScreen())),
        ),
        const SizedBox(height: 12),
        _TappableInfoCard(
          icon: Icons.format_list_bulleted_rounded,
          title: 'إعلانات وفرص الطلاب',
          body: 'استعرض الفرص المنشورة وشروطها ورابط التقديم.',
          onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const StudentListingsScreen(kind: 'opportunity'))),
        ),
        const SizedBox(height: 12),
        _TappableInfoCard(
          icon: Icons.school_outlined,
          title: 'منح الدراسات العليا',
          body: 'تصفّح المنح المتاحة وقدّم طلبك مباشرة.',
          onTap: (ctx) => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => const ScholarshipsScreen())),
        ),
      ];
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard(
      {required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.body),
              ])),
        ]),
      );
}

class _TappableInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final void Function(BuildContext) onTap;
  const _TappableInfoCard(
      {required this.icon,
      required this.title,
      required this.body,
      required this.onTap});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => onTap(context),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.body),
              ])),
          const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: AppColors.textSecondary),
        ]),
      );
}

// ─── شاشة المنح الدراسية ──────────────────────────────────────────────────────

class ScholarshipsScreen extends StatefulWidget {
  const ScholarshipsScreen({super.key});
  @override
  State<ScholarshipsScreen> createState() => _ScholarshipsScreenState();
}

class _ScholarshipsScreenState extends State<ScholarshipsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _all = [];
  List<dynamic> _mine = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = AuthSession.instance.token;
      final results = await Future.wait([
        ApiClient.instance.get('/scholarships'),
        ApiClient.instance.get('/scholarships/mine', token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List? ?? [];
        _mine = results[1] as List? ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل المنح. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'المنح الدراسية',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [Tab(text: 'المنح المتاحة'), Tab(text: 'طلباتي')],
            ),
          ),
          body: SafeArea(
            child: _loading
                ? const LoadingState(message: 'جاري تحميل المنح...')
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.navy,
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _AllScholarshipsTab(
                                items: _all,
                                appliedIds: _mine
                                    .map((e) =>
                                        '${(e is Map && e['scholarship'] is Map) ? (e['scholarship'] as Map)['_id'] : ''}')
                                    .toSet(),
                                onApplied: _load),
                            _MyScholarshipsTab(items: _mine),
                          ],
                        ),
                      ),
          ),
        ),
      );
}

class _AllScholarshipsTab extends StatelessWidget {
  final List items;
  final Set<String> appliedIds;
  final VoidCallback onApplied;
  const _AllScholarshipsTab(
      {required this.items,
      required this.appliedIds,
      required this.onApplied});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.school_outlined,
          title: 'لا توجد منح متاحة حاليًا',
          message: 'تابع هذه الصفحة للاطلاع على المنح عند إضافتها.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i] as Map;
        final id = '${item['_id']}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ScholarshipCard(
            item: item,
            applied: appliedIds.contains(id),
            onApplied: onApplied,
          ),
        );
      },
    );
  }
}

class _ScholarshipCard extends StatefulWidget {
  final Map item;
  final bool applied;
  final VoidCallback onApplied;
  const _ScholarshipCard(
      {required this.item, required this.applied, required this.onApplied});

  @override
  State<_ScholarshipCard> createState() => _ScholarshipCardState();
}

class _ScholarshipCardState extends State<_ScholarshipCard> {
  bool _applying = false;

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ApiClient.instance.post(
        '/scholarships/${widget.item['_id']}/apply',
        token: AuthSession.instance.token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تقديم طلب المنحة بنجاح')),
        );
        widget.onApplied();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ. أعد المحاولة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.item;
    final deadline = s['deadline'] != null ? _fmtDate(s['deadline']) : '';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s['title']}', style: AppTextStyles.cardTitle),
        const SizedBox(height: 6),
        if ('${s['university']}'.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.school_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${s['university']}', style: AppTextStyles.caption),
            if ('${s['country']}'.isNotEmpty) ...[
              const Text(' · ', style: AppTextStyles.caption),
              Text('${s['country']}', style: AppTextStyles.caption),
            ],
          ]),
          const SizedBox(height: 4),
        ],
        if ('${s['degree']}'.isNotEmpty) ...[
          Text('الدرجة: ${s['degree']}', style: AppTextStyles.caption),
          const SizedBox(height: 4),
        ],
        if ('${s['funding']}'.isNotEmpty) ...[
          Text('التمويل: ${s['funding']}',
              style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const SizedBox(height: 4),
        ],
        if ('${s['eligibility']}'.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('الشروط: ${s['eligibility']}',
              style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
        ],
        if (deadline.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.event_rounded,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text('آخر موعد: $deadline',
                style: const TextStyle(
                    color: AppColors.warning, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),
        widget.applied
            ? Row(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 6),
                const Text('تم التقديم',
                    style: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w600)),
              ])
            : _applying
                ? const Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.navy)))
                : ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button)),
                    ),
                    child: const Text('تقديم طلب المنحة'),
                  ),
      ]),
    );
  }
}

class _MyScholarshipsTab extends StatelessWidget {
  final List items;
  const _MyScholarshipsTab({required this.items});

  static const _statusLabels = {
    'submitted': 'تم التقديم',
    'reviewing': 'قيد المراجعة',
    'accepted': 'مقبول',
    'rejected': 'مرفوض',
  };
  static const _statusColors = {
    'submitted': AppColors.warning,
    'reviewing': AppColors.info,
    'accepted': AppColors.success,
    'rejected': AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.assignment_outlined,
          title: 'لم تتقدم لأي منحة بعد',
          message: 'تصفّح المنح المتاحة وقدّم طلبك.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final e = items[i] as Map;
        final s = e['scholarship'] is Map ? e['scholarship'] as Map : null;
        final status = '${e['status'] ?? 'submitted'}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s != null ? '${s['title']}' : 'منحة',
                        style: AppTextStyles.cardTitle),
                    if (s != null && '${s['university']}'.isNotEmpty)
                      Text('${s['university']}',
                          style: AppTextStyles.caption),
                    Text(_fmtDate(e['createdAt']),
                        style: AppTextStyles.caption),
                  ])),
              StatusBadge(
                label: _statusLabels[status] ?? status,
                color: _statusColors[status] ?? AppColors.neutral,
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─── وظائف وتدريب الخريجين (JobPost backend) ─────────────────────────────────

class JobPostsScreen extends StatefulWidget {
  const JobPostsScreen({super.key});
  @override
  State<JobPostsScreen> createState() => _JobPostsScreenState();
}

class _JobPostsScreenState extends State<JobPostsScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String? _error;

  static const _typeLabels = {
    'internship': 'تدريب',
    'part-time': 'دوام جزئي',
    'full-time': 'دوام كامل',
    'freelance': 'عمل حر',
    'volunteer': 'تطوع',
  };
  static const _typeColors = {
    'internship': AppColors.navy,
    'part-time': AppColors.info,
    'full-time': AppColors.success,
    'freelance': AppColors.orange,
    'volunteer': AppColors.warning,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.instance.get('/alumni/jobs', token: AuthSession.instance.token);
      if (mounted) setState(() => _posts = data is List ? data : []);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل الوظائف. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: const Text('سيتم حذف هذا الإعلان نهائيًا. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ApiClient.instance.delete('/alumni/jobs/$id', token: AuthSession.instance.token);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'وظائف وتدريب الخريجين',
    actions: [
      IconButton(
        tooltip: 'نشر إعلان',
        icon: const Icon(Icons.add_rounded),
        onPressed: () async {
          final posted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _PostJobScreen()));
          if (posted == true) _load();
        },
      ),
    ],
    body: _loading
        ? const LoadingState(message: 'جاري تحميل الوظائف...')
        : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.navy,
                child: _posts.isEmpty
                    ? const EmptyState(icon: Icons.work_outline_rounded, title: 'لا توجد وظائف منشورة بعد', message: 'كن أول من ينشر فرصة للطلاب!')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: _posts.length,
                        itemBuilder: (_, i) {
                          final p = Map<String, dynamic>.from(_posts[i] as Map);
                          final type = p['type'] as String? ?? 'internship';
                          final myId = AuthSession.instance.currentUser?.id ?? '';
                          final postedById = p['postedBy'] is Map ? '${(p['postedBy'] as Map)['_id']}' : '${p['postedBy']}';
                          final isOwn = postedById == myId;
                          return AppCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (_typeColors[type] ?? AppColors.navy).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(_typeLabels[type] ?? type, style: TextStyle(color: _typeColors[type] ?? AppColors.navy, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                                const Spacer(),
                                if (isOwn) IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), tooltip: 'حذف', onPressed: () => _delete('${p['_id']}')),
                              ]),
                              const SizedBox(height: 6),
                              Text('${p['title'] ?? ''}', style: AppTextStyles.cardTitle),
                              if ('${p['company'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.business_rounded, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('${p['company']}', style: AppTextStyles.caption),
                                  if ('${p['location'] ?? ''}'.isNotEmpty) ...[
                                    const Text(' · ', style: AppTextStyles.caption),
                                    Text('${p['location']}', style: AppTextStyles.caption),
                                  ],
                                ]),
                              ],
                              if ('${p['description'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('${p['description']}', style: AppTextStyles.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                              ],
                              if ('${p['contactEmail'] ?? ''}'.isNotEmpty || '${p['externalUrl'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(children: [
                                  if ('${p['externalUrl'] ?? ''}'.isNotEmpty)
                                    TextButton.icon(
                                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                      label: const Text('التقديم'),
                                      onPressed: () async {
                                        final uri = Uri.tryParse('${p['externalUrl']}');
                                        if (uri == null || (!uri.scheme.startsWith('http'))) return;
                                        try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
                                      },
                                    ),
                                  if ('${p['contactEmail'] ?? ''}'.isNotEmpty)
                                    TextButton.icon(
                                      icon: const Icon(Icons.email_outlined, size: 14),
                                      label: Text('${p['contactEmail']}', overflow: TextOverflow.ellipsis),
                                      onPressed: () async {
                                        final uri = Uri.parse('mailto:${p['contactEmail']}');
                                        try { await launchUrl(uri); } catch (_) {}
                                      },
                                    ),
                                ]),
                              ],
                            ]),
                          );
                        },
                      ),
              ),
  );
}

class _PostJobScreen extends StatefulWidget {
  const _PostJobScreen();
  @override
  State<_PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<_PostJobScreen> {
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _email = TextEditingController();
  final _url = TextEditingController();
  String _type = 'internship';
  bool _submitting = false;

  static const _types = ['internship', 'part-time', 'full-time', 'freelance', 'volunteer'];
  static const _typeLabels = {'internship': 'تدريب', 'part-time': 'دوام جزئي', 'full-time': 'دوام كامل', 'freelance': 'عمل حر', 'volunteer': 'تطوع'};

  @override
  void dispose() {
    for (final c in [_title, _company, _location, _description, _requirements, _email, _url]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل عنوان الوظيفة')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.post('/alumni/jobs', token: AuthSession.instance.token, body: {
        'title': _title.text.trim(),
        'company': _company.text.trim(),
        'location': _location.text.trim(),
        'type': _type,
        'description': _description.text.trim(),
        'requirements': _requirements.text.trim(),
        'contactEmail': _email.text.trim(),
        'externalUrl': _url.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر النشر. تأكد من وجود ملف خريج عام.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'نشر إعلان وظيفة',
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان الوظيفة *'), maxLength: 200),
        const SizedBox(height: 10),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'الشركة/المؤسسة'), maxLength: 200),
        const SizedBox(height: 10),
        TextField(controller: _location, decoration: const InputDecoration(labelText: 'الموقع (مدينة/دولة)'), maxLength: 200),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'نوع الفرصة'),
          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabels[t] ?? t))).toList(),
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 10),
        TextField(controller: _description, decoration: const InputDecoration(labelText: 'وصف الوظيفة'), maxLines: 4, maxLength: 3000),
        const SizedBox(height: 10),
        TextField(controller: _requirements, decoration: const InputDecoration(labelText: 'المتطلبات'), maxLines: 3, maxLength: 2000),
        const SizedBox(height: 10),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'البريد للتواصل'), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'رابط التقديم (https://...)'), keyboardType: TextInputType.url),
        const SizedBox(height: 20),
        PrimaryButton(label: _submitting ? 'جاري النشر...' : 'نشر الإعلان', onPressed: _submitting ? null : _submit),
      ]),
    ),
  );
}

