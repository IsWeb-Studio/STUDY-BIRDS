import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/student_events.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  late Future<List<StudentEvent>> future = loadCalendarEvents();
  void refresh() => setState(() => future = loadCalendarEvents());
  void move(int delta) => setState(() {
        month = DateTime(month.year, month.month + delta);
        selected = month;
      });
  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'التقويم',
        actions: [
          IconButton(
              onPressed: refresh,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh))
        ],
        body: FutureBuilder<List<StudentEvent>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingState();
              if (snapshot.hasError)
                return ErrorState(
                    message: 'تعذر تحميل المواعيد', onRetry: refresh);
              final events = snapshot.data ?? [];
              final daily = events
                  .where((e) => DateUtils.isSameDay(e.date, selected))
                  .toList();
              final monthly = events
                  .where((e) =>
                      e.date.year == month.year && e.date.month == month.month)
                  .length;
              final days = DateUtils.getDaysInMonth(month.year, month.month);
              final offset = month.weekday % 7;
              return RefreshIndicator(
                onRefresh: () async { refresh(); await future; },
                color: AppColors.navy,
                child: FeatureBody(children: [
                const FeatureIntro(
                    title: 'خطّط لخطوتك القادمة',
                    subtitle:
                        'مواعيدك المسجلة في مكان واحد؛ تابع استحقاقاتك وموعد وصولك.',
                    icon: Icons.calendar_month_outlined),
                FeaturePanel(
                    child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${arabicMonths[month.month - 1]} ${month.year}',
                              style: AppTextStyles.screenTitle),
                          Text('$monthly مواعيد هذا الشهر',
                              style: AppTextStyles.caption),
                        ])),
                    IconButton(
                        tooltip: 'الشهر السابق',
                        onPressed: () => move(-1),
                        icon: const Icon(Icons.chevron_right)),
                    IconButton(
                        tooltip: 'الشهر التالي',
                        onPressed: () => move(1),
                        icon: const Icon(Icons.chevron_left)),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    for (final day in [
                      'أحد',
                      'إثنين',
                      'ثلاثاء',
                      'أربعاء',
                      'خميس',
                      'جمعة',
                      'سبت'
                    ])
                      Expanded(
                          child: Text(day,
                              textAlign: TextAlign.center,
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 10)))
                  ]),
                  const SizedBox(height: 8),
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ((offset + days + 6) ~/ 7) * 7,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              mainAxisExtent: 48),
                      itemBuilder: (context, index) {
                        if (index < offset || index >= offset + days)
                          return const SizedBox.shrink();
                        final date = DateTime(
                            month.year, month.month, index - offset + 1);
                        final active = DateUtils.isSameDay(date, selected);
                        final today = DateUtils.isSameDay(date, DateTime.now());
                        final hasEvents = events
                            .any((e) => DateUtils.isSameDay(e.date, date));
                        return Semantics(
                            label: readableDate(date),
                            selected: active,
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => selected = date),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.navy
                                        : today
                                            ? AppColors.orange
                                                .withValues(alpha: .07)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: today && !active
                                        ? Border.all(color: AppColors.orange)
                                        : null),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('${date.day}',
                                          style: TextStyle(
                                              fontWeight: active || today
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: active
                                                  ? Colors.white
                                                  : AppColors.navy)),
                                      const SizedBox(height: 3),
                                      Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: hasEvents
                                                  ? AppColors.orange
                                                  : Colors.transparent)),
                                    ]),
                              ),
                            ));
                      }),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.circle, size: 6, color: AppColors.orange),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text('موعد مسجل', style: AppTextStyles.caption)),
                    TextButton(
                        onPressed: () => setState(() {
                              selected = DateUtils.dateOnly(DateTime.now());
                              month = DateTime(selected.year, selected.month);
                            }),
                        child: const Text('اليوم'))
                  ]),
                ])),
                Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 14),
                    child: Text(readableDate(selected),
                        style: AppTextStyles.cardTitle)),
                if (daily.isEmpty)
                  const FeaturePanel(
                      child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(children: [
                            Icon(Icons.event_available_outlined,
                                color: AppColors.textSecondary, size: 30),
                            SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('لا توجد مواعيد لهذا اليوم',
                                      style: AppTextStyles.cardTitle),
                                  SizedBox(height: 5),
                                  Text('اختر يومًا عليه نقطة لعرض مواعيده.',
                                      style: AppTextStyles.caption)
                                ])),
                          ]))),
                for (final event in daily)
                  FeaturePanel(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Container(
                            width: 4,
                            height: 44,
                            decoration: BoxDecoration(
                                color: AppColors.orange,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(event.title, style: AppTextStyles.cardTitle),
                              if (event.detail.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(event.detail,
                                        style: AppTextStyles.caption))
                            ])),
                      ])),
              ]),
              );
            }),
      );
}
