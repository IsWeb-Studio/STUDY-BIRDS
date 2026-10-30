import '../../core/services/error_reporter.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/consultation_repository.dart';
import 'consultation_outcome.dart';
import 'support_team_ai_screens.dart';

const kConsultationModes = {
  'online': 'أونلاين',
  'phone': 'هاتف',
  'office': 'مكتب',
};

class LiveConsultationScreen extends StatefulWidget {
  final VoidCallback? onBooked;
  final void Function(Map<String, dynamic> slot)? onSlotBooked;
  const LiveConsultationScreen({super.key, this.onBooked, this.onSlotBooked});
  @override
  State<LiveConsultationScreen> createState() => _LiveConsultationScreenState();
}

class _LiveConsultationScreenState extends State<LiveConsultationScreen> {
  final repo = ConsultationRepository.instance;
  List<Map<String, dynamic>> slots = [], bookings = [];
  Map<String, dynamic>? moving;
  bool loading = true, busy = false;
  String? error;
  String mode = 'all', advisor = 'all';
  DateTime? day;
  bool _pickingDay = false, _requesting = false, _requestSent = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([repo.slots(), repo.mine()]);
      if (!mounted) return;
      setState(() {
        slots = results[0];
        bookings = results[1];
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException && e.statusCode == 404
            ? 'خدمة المواعيد غير متاحة حاليًا. حاول لاحقًا أو تواصل مع الدعم.'
            : e is ApiException
                ? e.message
                : 'تعذر تحميل المواعيد. أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String when(dynamic raw) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) return 'موعد غير متاح';
    final local = MaterialLocalizations.of(context);
    return '${local.formatCompactDate(date)} — ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}';
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(title),
                content: Text(text),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد')),
                ],
              )) ??
      false;
  Future<void> reserve(Map<String, dynamic> slot) async {
    final previous = moving;
    if (!await confirm(
        previous == null ? 'تأكيد حجز الاستشارة' : 'تأكيد تغيير الموعد',
        '${slot['advisor']?['name'] ?? 'المستشار'}\n${when(slot['startsAt'])}\n${kConsultationModes[slot['mode']] ?? ''} — 30 دقيقة\nبتوقيت جهازك')) {
      return;
    }
    if (!mounted) return;
    Map<String, dynamic>? confirmed;
    await change(
        () async {
          confirmed = previous == null
              ? await repo.book(slot['_id'])
              : await repo.reschedule(previous, slot['_id']);
        },
        'تم تأكيد الموعد',
        onSuccess: () {
          widget.onBooked?.call();
          widget.onSlotBooked
              ?.call({...slot, ...?confirmed, 'advisor': slot['advisor']});
        });
  }

  Future<void> cancel(Map<String, dynamic> booking) async {
    if (!await confirm('إلغاء الاستشارة',
        'هل تريد إلغاء موعد ${when(booking['startsAt'])}؟')) {
      return;
    }
    if (mounted) await change(() => repo.cancel(booking), 'تم إلغاء الموعد');
  }

  Future<void> change(Future<void> Function() action, String message,
      {VoidCallback? onSuccess}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => moving = null);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackBar(content: Text(message)));
      onSuccess?.call();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'تعذر إتمام العملية. حدّث المواعيد وحاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickDay() async {
    if (_pickingDay) return;
    _pickingDay = true;
    try {
      final now = DateTime.now();
      final firstDate = DateUtils.dateOnly(now);
      final lastDate = DateUtils.dateOnly(now.add(const Duration(days: 90)));
      final dates = slots
          .where((slot) =>
              (mode == 'all' || slot['mode'] == mode) &&
              (advisor == 'all' || '${slot['advisor']?['_id']}' == advisor))
          .map((slot) => DateTime.tryParse('${slot['startsAt']}')?.toLocal())
          .whereType<DateTime>()
          .map(DateUtils.dateOnly)
          .where((date) => !date.isBefore(firstDate) && !date.isAfter(lastDate))
          .toSet()
          .toList()
        ..sort();
      final picked = await showDatePicker(
          context: context,
          initialDate: dates.isEmpty
              ? (day ?? firstDate)
              : dates.contains(day)
                  ? day
                  : dates.first,
          firstDate: firstDate,
          lastDate: lastDate,
          selectableDayPredicate: dates.isEmpty ? null : dates.contains);
      if (picked != null && mounted) setState(() => day = picked);
    } finally {
      _pickingDay = false;
    }
  }

  Future<void> requestConsultation() async {
    if (_requesting) return;
    if (day == null) {
      await pickDay();
      if (day == null || !mounted) return;
    }
    _requesting = true;
    try {
      final selectedAdvisor = slots
          .map((slot) => slot['advisor'])
          .whereType<Map>()
          .where((item) => '${item['_id']}' == advisor)
          .firstOrNull;
      final preferredDate =
          '${day!.year}-${day!.month.toString().padLeft(2, '0')}-${day!.day.toString().padLeft(2, '0')}';
      final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => NewSupportTicketScreen(
          initialSubject: 'طلب تنسيق موعد استشارة',
          initialMessage:
              'أرغب في تنسيق موعد استشارة.\nنوع الاستشارة: ${kConsultationModes[mode] ?? 'أي نوع متاح'}\nالمستشار المفضل: ${selectedAdvisor?['name'] ?? 'أي مستشار متاح'}\nالتاريخ المفضل بتوقيتي المحلي: $preferredDate\nهذا طلب تنسيق، والموعد غير مؤكد حتى يرد الفريق.',
        ),
      ));
      if (sent == true && mounted) setState(() => _requestSent = true);
    } finally {
      _requesting = false;
    }
  }

  Future<void> openMeeting(String raw) async {
    final uri = Uri.tryParse(raw);
    try {
      if (uri == null ||
          uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/services_support/live_consultation_screen.dart:162');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            AppSnackBar(content: const Text('تعذر فتح رابط الاجتماع.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final advisors = <String, String>{};
    for (final slot in slots) {
      final a = slot['advisor'];
      if (a is Map) advisors['${a['_id']}'] = '${a['name']}';
    }
    final selectedAdvisor = advisors.containsKey(advisor) ? advisor : 'all';
    final available = slots.where((slot) {
      final date = DateTime.tryParse('${slot['startsAt']}')?.toLocal();
      return (mode == 'all' || slot['mode'] == mode) &&
          (selectedAdvisor == 'all' ||
              '${slot['advisor']?['_id']}' == selectedAdvisor) &&
          (day == null || (date != null && DateUtils.isSameDay(date, day)));
    }).toList();
    const modes = kConsultationModes;
    return AppScaffold(
      title: 'حجز استشارة',
      actions: [
        IconButton(
            tooltip: 'تحديث المواعيد',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh))
      ],
      body: loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
          : RefreshIndicator(
              onRefresh: load,
              color: AppColors.navy,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text('مواعيدك بتوقيت جهازك — مدة الاستشارة 30 دقيقة',
                    style: AppTextStyles.caption),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: InlineNotice(error!, error: true)),
                const SizedBox(height: 12),
                const Text('استشاراتي', style: AppTextStyles.cardTitle),
                if (bookings.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child:
                          Text('ليس لديك حجز بعد. اختر موعدًا متاحًا أدناه.')),
                for (final booking in bookings) ...[
                  const SizedBox(height: 10),
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${booking['advisor']?['name'] ?? 'المستشار'} — ${when(booking['startsAt'])}',
                            style: AppTextStyles.body),
                        if (booking['outcome'] is Map)
                          ConsultationOutcomeView(
                              outcome:
                                  Map<String, dynamic>.from(booking['outcome']))
                        else
                          Text(booking['status'] == 'cancelled'
                              ? 'ملغاة'
                              : 'الحجز مؤكد'),
                        Text(modes[booking['slot']?['mode']] ?? ''),
                        if (booking['status'] == 'booked') ...[
                          if ('${booking['slot']?['instructions'] ?? ''}'
                              .isNotEmpty)
                            Text('${booking['slot']['instructions']}'),
                          if ('${booking['slot']?['meetingUrl'] ?? ''}'
                              .startsWith('https://'))
                            TextButton.icon(
                                onPressed: () =>
                                    openMeeting(booking['slot']['meetingUrl']),
                                icon: const Icon(Icons.video_call),
                                label: const Text('فتح رابط الاجتماع')),
                          if (DateTime.tryParse('${booking['startsAt']}')
                                  ?.isAfter(DateTime.now()) ==
                              true)
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(() {
                                            moving = booking;
                                            mode = 'all';
                                            advisor = 'all';
                                            day = null;
                                          }),
                                  child: const Text('تغيير الموعد')),
                              TextButton(
                                  onPressed:
                                      busy ? null : () => cancel(booking),
                                  child: const Text('إلغاء الحجز')),
                            ]),
                        ],
                      ])),
                ],
                const SizedBox(height: 22),
                Text(moving == null ? 'المواعيد المتاحة' : 'اختر الموعد البديل',
                    style: AppTextStyles.cardTitle),
                if (moving != null)
                  TextButton(
                      onPressed:
                          busy ? null : () => setState(() => moving = null),
                      child: const Text('الاحتفاظ بالموعد الحالي')),
                DropdownButton<String>(
                    isExpanded: true,
                    value: mode,
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('كل أنواع الاستشارة')),
                      ...modes.entries.map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                              mode = value!;
                              day = null;
                            })),
                DropdownButton<String>(
                    isExpanded: true,
                    value: selectedAdvisor,
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('كل المستشارين')),
                      ...advisors.entries.map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                              advisor = value!;
                              day = null;
                            })),
                Wrap(children: [
                  TextButton.icon(
                      onPressed: busy ? null : pickDay,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(day == null
                          ? slots.isEmpty
                              ? 'اختيار التاريخ المفضل'
                              : 'تصفية حسب التاريخ'
                          : MaterialLocalizations.of(context)
                              .formatCompactDate(day!))),
                  if (day != null)
                    TextButton(
                        onPressed: () => setState(() => day = null),
                        child: const Text('كل التواريخ'))
                ]),
                if (available.isEmpty && error == null) ...[
                  const InlineNotice(
                      'لا توجد مواعيد منشورة بهذه الخيارات. يمكنك اختيار تاريخ مفضل وإرسال طلب تنسيق للفريق. الطلب لا يؤكد حجزًا.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : requestConsultation,
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text('طلب تنسيق استشارة'),
                  ),
                  if (_requestSent)
                    const InlineNotice(
                        'تم إرسال طلبك. تابع رد الفريق في «تذاكري». لم يتم تأكيد موعد بعد.'),
                ],
                for (final slot in available)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${slot['advisor']?['name'] ?? 'المستشار'}'),
                      subtitle: Text(
                          '${when(slot['startsAt'])}\n${modes[slot['mode']] ?? ''}'),
                      isThreeLine: true,
                      trailing: FilledButton(
                          onPressed: busy ? null : () => reserve(slot),
                          child: Text(moving == null ? 'حجز' : 'اختيار'))),
              ])),
    );
  }
}
