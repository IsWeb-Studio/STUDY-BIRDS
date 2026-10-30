import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/stories_repository.dart';

String streakText(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

String streakDeadline(BuildContext context, DateTime? at) => at == null
    ? streakText(context, 'غير متاح حاليًا', 'Not available yet')
    : '${DateFormat('dd MMM · HH:mm', Localizations.localeOf(context).languageCode).format(at.toUtc())} UTC';

String streakCountdown(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

// The old activity dashboard is intentionally absent from account pages.
class MyStreakCard extends StatelessWidget {
  final bool isActive;
  final Future<StoryProgress> Function()? load;
  const MyStreakCard({super.key, this.isActive = true, this.load});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
                                        ? AppColors.green.withValues(alpha: .12)
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
                                              color: AppColors.green, size: 16),
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

class StreakDetailsSheet extends StatelessWidget {
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
  Widget build(BuildContext context) => StreakRulesSheet(
      timeZone: initial.timeZone, isGameActivity: isGameActivity);
}

class StreakRulesSheet extends StatelessWidget {
  final String timeZone;
  final bool isGameActivity;
  const StreakRulesSheet(
      {super.key, required this.timeZone, this.isGameActivity = false});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: _StreakRulesCard(
                isGameActivity: isGameActivity, timeZone: timeZone),
          ),
        ),
      );
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
                'تزيد السلسلة يومًا واحدًا عند المشاركة في جولة أونلاين فعلية، مرة في اليوم حسب $timeZone. فتح اللعبة أو انتظار الغرفة أو التدريب أو اللعب دون اتصال لا يُحتسب.',
                'تنتهي السلسلة بعد 36 ساعة من آخر مشاركة محتسبة، وتبدأ بعدها مهلة استرجاع مدتها 24 ساعة. انقطاع السلسلة لا يحذف نقاطك.',
                'لك 3 استرجاعات في الشهر حسب $timeZone. لا ينتقل المتبقي للشهر التالي، وتجديد الرصيد لا يعيد مهلة استرجاع انتهت.',
                'نشر الستوريات واللايكات لا يمدّد ستريك اللعب. استرجاع السلسلة لا يمنح نقاطًا إضافية.',
              ]
            : [
                'Your streak advances once per calendar day in $timeZone through a real online round. Opening the game, waiting in a lobby, practice and offline play do not count.',
                'The streak expires 36 hours after your last qualifying game, followed by a 24-hour recovery window. Your points remain when a streak breaks.',
                'You get 3 restores per calendar month in $timeZone. Unused restores do not roll over, and a monthly reset never reopens an expired recovery window.',
                'Stories and likes do not extend the game streak. Restoring a streak awards no extra points.',
              ])
        : (isArabic
            ? [
                'انشر ستوري ليزيد الستريك يومًا واحدًا، مرة في اليوم حسب $timeZone. نشر ستوريات إضافية في اليوم نفسه لا يزيد عدد الأيام.',
                'تنتهي السلسلة بعد 36 ساعة من آخر ستوري، وتبدأ بعدها مهلة استرجاع مدتها 24 ساعة. انقطاع السلسلة لا يحذف نقاطك.',
                'لك 3 استرجاعات في الشهر حسب $timeZone. لا ينتقل المتبقي للشهر التالي، وتجديد الرصيد لا يعيد مهلة استرجاع انتهت.',
                'اللايكات واللعبة لا يمدّدان ستريك الستوريات. استرجاع السلسلة لا يمنح نقاطًا إضافية.',
              ]
            : [
                'Publish a story to advance your streak once per calendar day in $timeZone. Extra stories on the same day do not add more streak days.',
                'The streak expires 36 hours after your last story, followed by a 24-hour recovery window. Your points remain when a streak breaks.',
                'You get 3 restores per calendar month in $timeZone. Unused restores do not roll over, and a monthly reset never reopens an expired recovery window.',
                'Likes and games do not extend your story streak. Restoring a streak awards no extra points.',
              ]);
    final points = isArabic
        ? [
            'أول ستوري تنشره يوميًا: +100 نقطة. الستوريات الإضافية في اليوم نفسه لا تمنح نقاط نشر جديدة.',
            if (!isGameActivity)
              'كل 7 أيام ستريك: +300 نقطة إضافية، عند الوصول إلى اليوم 7 و14 و21 وهكذا.',
            if (!isGameActivity)
              'اللعب أونلاين: +10 نقاط لأول مشاركة مؤهلة يوميًا في جولة بدأت وبها لاعبان حقيقيان على الأقل. فتح اللعبة أو الانتظار أو التدريب أو اللعب دون اتصال لا يمنح هذه النقاط.'
            else
              'اللعب أونلاين يحافظ على ستريك اللعب لهذا الحساب، لكنه لا يمنح مكافأة الـ10 نقاط الخاصة بحساب الطالب.',
            'لايك لستوري شخص آخر: +5 نقاط لأول 10 لايكات يوميًا على ستوريات مختلفة، بحد أقصى 50 نقطة في اليوم.',
            'استقبال لايك جديد على ستوريك من شخص آخر: +50 نقطة لك.',
            'اللايك على ستوريك لا يمنح نقاطًا. تكرار اللايك على الستوري نفسه لا يمنح نقاطًا إضافية. يبدأ الحد اليومي من جديد حسب $timeZone.',
          ]
        : [
            'First story each day: +100 points. Extra stories on the same day earn no additional publishing points.',
            if (!isGameActivity)
              'Every 7 streak days: +300 bonus points at days 7, 14, 21 and so on.',
            if (!isGameActivity)
              'Online play: +10 points for your first qualifying participation each day in a started round with at least two real players. Opening the game, waiting in a lobby, practice and offline play earn none.'
            else
              'Online play maintains this account’s game streak, but does not award the 10-point student bonus.',
            'Like another person’s story: +5 points for your first 10 likes on different stories each day, up to 50 points per day.',
            'Receive a new like on your story from another person: +50 points for you.',
            'Liking your own story earns no points. Repeated likes on the same story earn no extra points. Daily limits reset by the calendar day in $timeZone.',
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _RulesPanel(
        icon: Icons.local_fire_department_outlined,
        title: isArabic ? 'قواعد الستريك' : 'Streak rules',
        lines: rules,
      ),
      const SizedBox(height: 16),
      _RulesPanel(
        icon: Icons.stars_outlined,
        title: isArabic ? 'كيف تجمع النقاط؟' : 'How do you earn points?',
        lines: points,
      ),
    ]);
  }
}

class _RulesPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _RulesPanel(
      {required this.icon, required this.title, required this.lines});

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
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.5))),
                    ],
                  ),
                )),
          ],
        ),
      );
}
