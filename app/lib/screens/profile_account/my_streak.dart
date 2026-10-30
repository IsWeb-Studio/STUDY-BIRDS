import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import '../../core/widgets/streak_restore.dart';

String streakText(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

String streakDeadline(BuildContext context, DateTime? at) => at == null
    ? streakText(context, 'غير متاح حاليًا', 'Not available yet')
    : '${DateFormat('dd MMM · HH:mm', Localizations.localeOf(context).languageCode).format(at.toUtc())} UTC';

String streakCountdown(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

String _scope() =>
    '${AuthSession.instance.currentUser?.id ?? ''}:${AuthSession.instance.token ?? ''}';

class MyStreakCard extends StatefulWidget {
  final bool isActive;
  final Future<StoryProgress> Function()? load;
  const MyStreakCard({super.key, this.isActive = true, this.load});
  @override
  State<MyStreakCard> createState() => _MyStreakCardState();
}

class _MyStreakCardState extends State<MyStreakCard>
    with WidgetsBindingObserver {
  StoryProgress? _progress;
  Object? _error;
  bool _loading = false, _opening = false;
  int _generation = 0;
  late String _owner;
  StreamSubscription<void>? _changes;
  Timer? _refresh;
  bool get _isAgent => AuthSession.instance.currentUser?.role == UserRole.agent;
  bool get _usesGameActivity {
    final role = AuthSession.instance.currentUser?.role;
    return role != null && role != UserRole.student && role != UserRole.agent;
  }

  @override
  void initState() {
    super.initState();
    _owner = _scope();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_sessionChanged);
    _changes = StoriesRepository.instance.changes.listen((_) {
      if (widget.isActive) _load();
    });
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (widget.isActive &&
          (ModalRoute.isCurrentOf(context) ?? true) &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        _load();
      }
    });
    if (widget.isActive && !_isAgent) _load();
  }

  void _sessionChanged() {
    if (_owner == _scope()) return;
    _owner = _scope();
    _generation++;
    setState(() {
      _progress = null;
      _error = null;
      _loading = false;
    });
    if (widget.isActive && !_isAgent) _load();
  }

  @override
  void didUpdateWidget(covariant MyStreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_isAgent) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive && !_isAgent) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || _isAgent) return;
    final version = ++_generation, owner = _owner;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final progress =
          await (widget.load?.call() ?? StoriesRepository.instance.progress());
      if (mounted && version == _generation && owner == _scope()) {
        setState(() => _progress = progress);
      }
    } catch (error) {
      if (mounted && version == _generation && owner == _scope()) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && version == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_opening || _progress == null) return;
    _opening = true;
    final owner = _owner;
    try {
      await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 600),
          sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          builder: (_) => StreakDetailsSheet(
              initial: _progress!,
              isGameActivity: _usesGameActivity,
              onChanged: (value) {
                if (mounted && owner == _scope()) {
                  setState(() => _progress = value);
                }
              }));
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _changes?.cancel();
    _refresh?.cancel();
    AuthSession.instance.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _isAgent
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: StreakSummary(
              progress: _progress,
              loading: _loading,
              error: _error,
              isGameActivity: _usesGameActivity,
              onTap: _progress == null ? _load : _open,
              onRetry: _load));
}

class StreakSummary extends StatelessWidget {
  final StoryProgress? progress;
  final bool loading;
  final Object? error;
  final VoidCallback? onTap, onRetry;
  final String? title;
  final bool isGameActivity;
  const StreakSummary(
      {super.key,
      this.progress,
      this.loading = false,
      this.error,
      this.onTap,
      this.onRetry,
      this.title,
      this.isGameActivity = false});
  @override
  Widget build(BuildContext context) {
    final p = progress;
    final theme = Theme.of(context), scheme = Theme.of(context).colorScheme;
    final active = (p?.days ?? 0) > 0;
    final risk = p?.streakState == 'at_risk';
    final recovering = p?.streakState == 'recoverable';
    final title = this.title ?? streakText(context, 'سلسلة نشاطي', 'My Streak');
    final status = p == null
        ? ''
        : risk
            ? '${streakText(context, isGameActivity ? 'العب قبل' : 'انشر قبل', isGameActivity ? 'Play before' : 'Post before')} ${streakDeadline(context, p.resetsAt)}'
            : recovering
                ? streakText(
                    context,
                    isGameActivity
                        ? 'فرصة لاستعادة سلسلة اللعب'
                        : 'فرصة لاستعادة نشاطك',
                    isGameActivity
                        ? 'Your game streak can be restored'
                        : 'Your streak can be restored')
                : active
                    ? streakText(
                        context,
                        isGameActivity
                            ? 'اللعب أونلاين يحافظ على استمرار سلسلتك'
                            : 'خطوة صغيرة كل يوم',
                        isGameActivity
                            ? 'Your online play keeps this streak going'
                            : 'A little progress, every day')
                    : streakText(
                        context,
                        isGameActivity
                            ? 'ابدأ سلسلة جديدة بالمشاركة في لعبة أونلاين'
                            : 'ابدأ سلسلة جديدة بنشر ستوري',
                        isGameActivity
                            ? 'Start a new streak by playing online'
                            : 'Start a new streak by sharing a story');
    return Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.green
                                            .withValues(alpha: .12)
                                        : scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(
                                    risk
                                        ? Icons.hourglass_top_rounded
                                        : active || recovering
                                            ? Icons
                                                .local_fire_department_rounded
                                            : Icons.calendar_today_outlined,
                                    color: active
                                        ? AppColors.green
                                        : scheme.onSurfaceVariant,
                                    size: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  if (p != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(status,
                                            style: theme.textTheme.bodySmall)),
                                  if (p != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 7),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.stars_rounded,
                                              color: AppColors.green,
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '${NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(p.points)} ${streakText(context, 'نقطة', 'points')}',
                                              key: const ValueKey(
                                                  'my-streak-points'),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ])),
                            if (p != null)
                              Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 8),
                                  child: Column(children: [
                                    AnimatedSwitcher(
                                        duration: MediaQuery
                                                .disableAnimationsOf(context)
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        child: Text(
                                            '${active ? p.days : recovering ? p.recoverableDays : 0}',
                                            key: ValueKey(
                                                '${p.streakState}:${p.days}:${p.recoverableDays}'),
                                            style: theme
                                                .textTheme.headlineMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700))),
                                    Text(streakText(context, 'يوم', 'days'),
                                        style: theme.textTheme.labelSmall),
                                  ])),
                          ]),
                      if (p == null && loading) ...[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                            minHeight: 2,
                            semanticsLabel: streakText(
                                context, 'تحميل النشاط', 'Loading streak')),
                      ],
                      if (p != null && p.calendar.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Week(
                            days: p.calendar.length > 7
                                ? p.calendar.sublist(p.calendar.length - 7)
                                : p.calendar),
                      ],
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(children: [
                              Expanded(
                                  child: Text(
                                      error is SocketException ||
                                              error is TimeoutException
                                          ? streakText(
                                              context,
                                              'أنت غير متصل. أعد المحاولة عند عودة الاتصال.',
                                              'You are offline. Try again when connected.')
                                          : streakText(
                                              context,
                                              'تعذر تحديث النشاط. بيانات الاسترجاع تحتاج اتصالًا.',
                                              'Could not refresh. Recovery requires a connection.'),
                                      style: theme.textTheme.bodySmall)),
                              IconButton(
                                  onPressed: onRetry,
                                  tooltip: streakText(
                                      context, 'إعادة المحاولة', 'Retry'),
                                  icon: const Icon(Icons.refresh)),
                            ])),
                    ]))));
  }
}

class _Week extends StatelessWidget {
  final List<StreakDay> days;
  const _Week({required this.days});
  @override
  Widget build(BuildContext context) => Row(
          children: days.map((day) {
        final at = DateTime.parse('${day.day}T00:00:00Z');
        final scheme = Theme.of(context).colorScheme;
        return Expanded(
            child: Semantics(
                label:
                    '${day.day}, ${streakText(context, day.active ? 'نشط' : 'دون نشاط', day.active ? 'active' : 'no activity')}',
                child: Column(children: [
                  Text(
                      DateFormat('EEEEE',
                              Localizations.localeOf(context).languageCode)
                          .format(at),
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 5),
                  Icon(
                      day.active
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 17,
                      color: day.active ? AppColors.green : scheme.outline),
                ])));
      }).toList());
}

class StreakDetailsSheet extends StatefulWidget {
  final StoryProgress initial;
  final bool isGameActivity;
  final ValueChanged<StoryProgress>? onChanged;
  final Future<StoryProgress> Function()? load;
  final Future<StoryProgress> Function(String)? restore;
  const StreakDetailsSheet(
      {super.key,
      required this.initial,
      this.isGameActivity = false,
      this.onChanged,
      this.load,
      this.restore});
  @override
  State<StreakDetailsSheet> createState() => _StreakDetailsSheetState();
}

class _StreakDetailsSheetState extends State<StreakDetailsSheet>
    with WidgetsBindingObserver {
  late StoryProgress _progress;
  late String _owner;
  Timer? _timer;
  bool _loading = false, _failed = false, _refreshedDeadline = false;
  @override
  void initState() {
    super.initState();
    _progress = widget.initial;
    _owner = _scope();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_session);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final deadline =
          _progress.days > 0 ? _progress.resetsAt : _progress.recoveryExpiresAt;
      if (!_refreshedDeadline &&
          _progress.serverNow != null &&
          deadline != null &&
          _progress.remainingUntil(deadline) == Duration.zero) {
        _refreshedDeadline = true;
        _load();
      }
    });
  }

  void _session() {
    if (_owner != _scope() && mounted) {
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final p = await (widget.load?.call() ??
          StoriesRepository.instance.streakDetails());
      if (mounted && _owner == _scope()) {
        setState(() {
          _progress = p;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.removeListener(_session);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_owner != _scope()) return const SizedBox.shrink();
    final p = _progress;
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: ListView(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Row(children: [
                Expanded(
                    child: Text(streakText(context, 'سلسلة نشاطي', 'My Streak'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: streakText(context, 'إغلاق', 'Close'),
                    icon: const Icon(Icons.close))
              ]),
              const SizedBox(height: 12),
              StreakSummary(
                  progress: p,
                  isGameActivity: widget.isGameActivity,
                  title:
                      streakText(context, 'سلسلتك الحالية', 'Current streak')),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 2)),
              if (_failed)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(streakText(
                        context,
                        'تعذر التحديث. الاسترجاع متوقف حتى عودة الاتصال.',
                        'Could not refresh. Recovery is paused until connected.')),
                    trailing: IconButton(
                        onPressed: _load,
                        tooltip: streakText(context, 'إعادة المحاولة', 'Retry'),
                        icon: const Icon(Icons.refresh))),
              const SizedBox(height: 16),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.emoji_events_outlined),
                  title:
                      Text(streakText(context, 'أطول سلسلة', 'Longest streak')),
                  trailing: Text(
                      '${p.longestStreak} ${streakText(context, 'يوم', 'days')}',
                      style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 8),
              _StreakRulesCard(
                  isGameActivity: widget.isGameActivity, timeZone: p.timeZone),
              const SizedBox(height: 12),
              _StreakPointsCard(
                  progress: p, isGameActivity: widget.isGameActivity),
              const SizedBox(height: 12),
              Text(streakText(context, 'نشاطك الأخير', 'Recent activity'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (p.calendar.isEmpty)
                Text(p.serverNow == null
                    ? streakText(context, 'سجل النشاط غير متاح حاليًا.',
                        'Activity history is not available yet.')
                    : streakText(
                        context,
                        widget.isGameActivity
                            ? 'سيظهر نشاطك هنا بعد أول مشاركة في لعبة أونلاين.'
                            : 'سيظهر نشاطك هنا بعد أول ستوري.',
                        widget.isGameActivity
                            ? 'Your activity appears here after your first online game.'
                            : 'Your activity appears here after your first story.'))
              else
                GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: p.calendar
                        .map((day) => Tooltip(
                            message: '${day.day} · ${p.timeZone}',
                            child: Semantics(
                                label:
                                    '${day.day}, ${day.active ? streakText(context, 'نشط', 'active') : streakText(context, 'دون نشاط', 'no activity')}',
                                child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: day.active
                                            ? AppColors.green
                                                .withValues(alpha: .16)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                        border: day.active ? Border.all(color: AppColors.green) : null),
                                    child: Text(day.day.substring(8), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: day.active ? FontWeight.bold : FontWeight.normal))))))
                        .toList()),
              const SizedBox(height: 20),
              StreakRestore(
                  progress: p,
                  isGameActivity: widget.isGameActivity,
                  allowActions: !_failed && !_loading,
                  restore: widget.restore,
                  onRefreshNeeded: _load,
                  onRestored: (value) {
                    if (!mounted || _owner != _scope()) return;
                    setState(() {
                      _progress = value;
                      _refreshedDeadline = false;
                    });
                    widget.onChanged?.call(value);
                    _load();
                  }),
            ]));
  }
}

class _StreakRulesCard extends StatelessWidget {
  final bool isGameActivity;
  final String timeZone;
  const _StreakRulesCard(
      {required this.isGameActivity, required this.timeZone});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rules = isGameActivity
        ? (isArabic
            ? [
                'تُحتسب مشاركة فعلية في لعبة أونلاين مرة واحدة في اليوم؛ اللعب التدريبي أو دون اتصال لا يُحتسب.',
                'تنتهي السلسلة بعد 36 ساعة من آخر مشاركة، وتبدأ بعدها مهلة استرجاع مدتها 24 ساعة.',
                'لك 3 استرجاعات في الشهر حسب $timeZone. لا ينتقل المتبقي للشهر التالي، وتجديد الرصيد لا يعيد مهلة استرجاع انتهت.',
              ]
            : [
                'One real online game participation counts per day; practice or offline play does not count.',
                'The streak expires 36 hours after your last qualifying game, followed by a 24-hour recovery window.',
                'You get 3 restores per calendar month in $timeZone. Unused restores do not roll over, and a monthly reset never reopens an expired recovery window.',
              ])
        : (isArabic
            ? [
                'ينمو ستريك الطالب عند نشر ستوري: يُحتسب يوم نشاط واحد كحد أقصى في اليوم.',
                'تنتهي السلسلة بعد 36 ساعة من آخر ستوري، وتبدأ بعدها مهلة استرجاع مدتها 24 ساعة.',
                'لك 3 استرجاعات في الشهر حسب $timeZone. لا ينتقل المتبقي للشهر التالي، وتجديد الرصيد لا يعيد مهلة استرجاع انتهت.',
              ]
            : [
                'Student story streaks advance from story publishing, at most once per calendar day.',
                'The streak expires 36 hours after your last story, followed by a 24-hour recovery window.',
                'You get 3 restores per calendar month in $timeZone. Unused restores do not roll over, and a monthly reset never reopens an expired recovery window.',
              ]);
    return _RulesPanel(
      icon: Icons.local_fire_department_outlined,
      title: isArabic ? 'قواعد الستريك' : 'Streak rules',
      lines: rules,
    );
  }
}

class _StreakPointsCard extends StatelessWidget {
  final StoryProgress progress;
  final bool isGameActivity;
  const _StreakPointsCard(
      {required this.progress, required this.isGameActivity});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isStudent =
        AuthSession.instance.currentUser?.role == UserRole.student;
    final lines = <String>[
      isArabic
          ? 'أول ستوري في اليوم يمنحك 100 نقطة. الستوري الإضافي في اليوم نفسه لا يمنح نقاط نشر إضافية.'
          : 'Your first story each day earns 100 points. Additional stories that day earn no extra posting points.',
      if (isStudent)
        isArabic
            ? 'كل 7 أيام متتالية من نشاط الستوري تمنح مكافأة 300 نقطة.'
            : 'Each 7-day story-streak milestone adds a 300-point bonus.'
      else
        isArabic
            ? 'نشر الستوري يمنح نقاطًا، لكنه لا يقدّم ستريك اللعب؛ الستريك يرتفع بالمشاركة الفعلية في لعبة أونلاين.'
            : 'Stories earn points but do not advance your game streak; qualifying online play advances it.',
      isArabic
          ? 'تحصل على 5 نقاط لأول 10 إعجابات تمنحها يوميًا، ويحصل صاحب الستوري على 50 نقطة من أول إعجاب لكل شخص مختلف.'
          : 'You earn 5 points for each of your first 10 likes per day; a story owner earns 50 points from each different member’s first like.',
    ];
    if (isGameActivity && isStudent) {
      lines.add(isArabic
          ? 'اللعب الحقيقي أونلاين يمنح الطالب 10 نقاط مرة واحدة يوميًا، لكنه لا يغيّر ستريك الطالب المعتمد على الستوري.'
          : 'A real online game gives students 10 points once per day, but does not change the student’s story-based streak.');
    }
    return _RulesPanel(
      icon: Icons.stars_rounded,
      title:
          isArabic ? 'نقاطي وقواعد احتسابها' : 'My points and how they count',
      balance:
          '${NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(progress.points)} ${isArabic ? 'نقطة' : 'points'}',
      lines: lines,
    );
  }
}

class _RulesPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? balance;
  final List<String> lines;
  const _RulesPanel(
      {required this.icon,
      required this.title,
      required this.lines,
      this.balance});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            if (balance != null) ...[
              const SizedBox(height: 4),
              Text(balance!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.green, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 10),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 5),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Text(line,
                              style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                )),
          ],
        ),
      );
}
