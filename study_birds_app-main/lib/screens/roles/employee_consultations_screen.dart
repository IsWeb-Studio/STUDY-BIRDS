import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/consultation_repository.dart';
import '../services_support/consultation_outcome.dart';

const _kModes = {'online': 'أونلاين', 'phone': 'هاتف', 'office': 'مكتب'};

String _when(BuildContext context, dynamic raw) {
  final date = DateTime.tryParse('$raw')?.toLocal();
  if (date == null) return 'موعد غير متاح';
  final local = MaterialLocalizations.of(context);
  return '${local.formatCompactDate(date)} — ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}';
}

/// Staff-side availability & booking management for the 'consultations'
/// section (server/src/routes/consultationRoutes.js `/staff/*`). Admins see
/// and publish for every consultant; other staff only see and manage their
/// own slots and bookings, matching the web's /admin/consultations page.
class EmployeeConsultationsScreen extends StatefulWidget {
  const EmployeeConsultationsScreen({super.key});
  @override
  State<EmployeeConsultationsScreen> createState() =>
      _EmployeeConsultationsScreenState();
}

class _EmployeeConsultationsScreenState
    extends State<EmployeeConsultationsScreen> {
  final repo = ConsultationRepository.instance;
  List<Map<String, dynamic>> advisors = [], slots = [], bookings = [];
  bool loading = true, busy = false;
  String? error;

  bool get isAdmin => AuthSession.instance.currentUser?.role == UserRole.admin;

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
      final results = await Future.wait(
          [repo.staffAdvisors(), repo.staffSlots(), repo.staffBookings()]);
      if (!mounted) return;
      setState(() {
        advisors = results[0];
        slots = results[1];
        bookings = results[2];
      });
    } catch (e) {
      if (mounted) {
        setState(() => error =
            e is ApiException ? e.message : 'تعذر تحميل مواعيد الاستشارات.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openPublishForm() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => _PublishConsultationSlotScreen(advisors: advisors)));
    if (created == true) await load();
  }

  Future<void> editOutcome(Map<String, dynamic> booking) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ConsultationOutcomeEditor(booking: booking)));
    if (saved == true && mounted) await load();
  }

  Future<void> toggleSlot(Map<String, dynamic> slot, bool enabled) async {
    if (!enabled &&
        !await showAppConfirmDialog(context,
            title: 'تعطيل الموعد',
            message:
                'لن يظهر هذا الموعد للطلاب بعد التعطيل. يمكنك إعادة تفعيله لاحقًا.',
            confirmLabel: 'تعطيل',
            danger: true)) {
      return;
    }
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.setSlotEnabled(slot, enabled);
      if (!mounted) return;
      await load();
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e is ApiException ? e.message : 'تعذر تحديث حالة الموعد.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancelBooking(Map<String, dynamic> booking) async {
    if (!await showAppConfirmDialog(context,
        title: 'إلغاء الحجز',
        message:
            'هل تريد إلغاء حجز ${booking['student']?['name'] ?? 'الطالب'} في ${_when(context, booking['startsAt'])}؟',
        confirmLabel: 'إلغاء الحجز',
        danger: true)) {
      return;
    }
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.cancel(booking);
      if (!mounted) return;
      await load();
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is ApiException ? e.message : 'تعذر إلغاء الحجز.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح رابط الاجتماع.')));
      }
    }
  }

  String _slotStatus(Map<String, dynamic> slot) {
    final starts = DateTime.tryParse('${slot['startsAt']}');
    if (slot['reservation'] != null) return 'booked';
    if (starts == null || !starts.isAfter(DateTime.now())) return 'past';
    if (slot['enabled'] == false) return 'disabled';
    return 'available';
  }

  @override
  Widget build(BuildContext context) {
    final upcomingBookings = bookings
        .where((b) =>
            b['status'] == 'booked' &&
            DateTime.tryParse('${b['startsAt']}')?.isAfter(DateTime.now()) ==
                true)
        .toList();
    return AppScaffold(
      title: 'الاستشارات والمواعيد',
      actions: [
        IconButton(
            tooltip: 'تحديث',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh)),
        IconButton(
            tooltip: 'نشر موعد جديد',
            onPressed: busy || loading ? null : openPublishForm,
            icon: const Icon(Icons.add_circle_outline_rounded)),
      ],
      body: loading
          ? const LoadingState()
          : RefreshIndicator(
              onRefresh: load,
              color: AppColors.navy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                      isAdmin
                          ? 'تدير هنا مواعيد جميع المستشارين. الأوقات بتوقيت جهازك.'
                          : 'تدير هنا مواعيدك الخاصة فقط. الأوقات بتوقيت جهازك.',
                      style: AppTextStyles.caption),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(error!,
                            style: const TextStyle(color: AppColors.danger))),
                  const SizedBox(height: 16),
                  const Text('حجوزات الطلاب القادمة',
                      style: AppTextStyles.cardTitle),
                  if (upcomingBookings.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('لا توجد حجوزات قادمة حاليًا.')),
                  for (final booking in upcomingBookings) ...[
                    const SizedBox(height: 10),
                    AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '${booking['student']?['name'] ?? 'طالب'} — ${_when(context, booking['startsAt'])}',
                              style: AppTextStyles.body),
                          if (isAdmin)
                            Text(
                                'المستشار: ${booking['advisor']?['name'] ?? ''}',
                                style: AppTextStyles.caption),
                          Text(_kModes[booking['slot']?['mode']] ?? ''),
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
                          Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => cancelBooking(booking),
                                  child: const Text('إلغاء الحجز'))),
                        ])),
                  ],
                  const SizedBox(height: 22),
                  const Text('نتائج الاستشارات السابقة',
                      style: AppTextStyles.cardTitle),
                  for (final booking in bookings.where((b) {
                    final start = DateTime.tryParse('${b['startsAt']}');
                    return b['status'] != 'cancelled' &&
                        start != null &&
                        !start
                            .add(const Duration(minutes: 30))
                            .isAfter(DateTime.now());
                  })) ...[
                    const SizedBox(height: 10),
                    AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '${booking['student']?['name'] ?? 'طالب'} — ${_when(context, booking['startsAt'])}'),
                          if (isAdmin)
                            Text(
                                'المستشار: ${booking['advisor']?['name'] ?? ''}'),
                          if (booking['outcome'] is Map)
                            ConsultationOutcomeView(
                                outcome: Map<String, dynamic>.from(
                                    booking['outcome']))
                          else
                            const Text('بانتظار تسجيل نتيجة الاستشارة'),
                          TextButton(
                              onPressed:
                                  busy ? null : () => editOutcome(booking),
                              child: Text(booking['outcome'] is Map
                                  ? 'تعديل النتيجة'
                                  : 'تسجيل النتيجة')),
                        ])),
                  ],
                  const SizedBox(height: 22),
                  const Text('المواعيد المنشورة',
                      style: AppTextStyles.cardTitle),
                  if (slots.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                            'لم تُنشر أي مواعيد بعد. استخدم زر الإضافة أعلى الشاشة.')),
                  for (final slot in slots) ...[
                    const SizedBox(height: 10),
                    AppCard(
                        child: Row(
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(_when(context, slot['startsAt']),
                                  style: AppTextStyles.body),
                              if (isAdmin)
                                Text(
                                    'المستشار: ${slot['advisor']?['name'] ?? ''}',
                                    style: AppTextStyles.caption),
                              Text(_kModes[slot['mode']] ?? '',
                                  style: AppTextStyles.caption),
                            ])),
                        _slotStatusBadge(_slotStatus(slot)),
                        if (_slotStatus(slot) == 'available' ||
                            _slotStatus(slot) == 'disabled')
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => toggleSlot(
                                      slot, _slotStatus(slot) == 'disabled'),
                              child: Text(_slotStatus(slot) == 'disabled'
                                  ? 'تفعيل'
                                  : 'تعطيل')),
                      ],
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _slotStatusBadge(String status) {
    switch (status) {
      case 'booked':
        return const StatusBadge(label: 'محجوز', color: AppColors.info);
      case 'disabled':
        return const StatusBadge(
            label: 'معطّل', color: AppColors.textSecondary);
      case 'past':
        return const StatusBadge(
            label: 'منتهٍ', color: AppColors.textSecondary);
      default:
        return const StatusBadge(label: 'متاح', color: AppColors.success);
    }
  }
}

class _PublishConsultationSlotScreen extends StatefulWidget {
  final List<Map<String, dynamic>> advisors;
  const _PublishConsultationSlotScreen({required this.advisors});

  @override
  State<_PublishConsultationSlotScreen> createState() =>
      _PublishConsultationSlotScreenState();
}

class _PublishConsultationSlotScreenState
    extends State<_PublishConsultationSlotScreen> {
  final meetingUrl = TextEditingController();
  final instructions = TextEditingController();
  String? advisorId;
  String mode = 'online';
  int occurrences = 1;
  DateTime? day;
  TimeOfDay? time;
  bool saving = false;
  String? error;

  bool get isAdmin => AuthSession.instance.currentUser?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (widget.advisors.length == 1) {
      advisorId = widget.advisors.single['_id'] as String?;
    } else if (!isAdmin) {
      advisorId = AuthSession.instance.currentUser?.id;
    }
  }

  @override
  void dispose() {
    meetingUrl.dispose();
    instructions.dispose();
    super.dispose();
  }

  List<TimeOfDay> get _halfHours =>
      List.generate(48, (i) => TimeOfDay(hour: i ~/ 2, minute: (i % 2) * 30));

  List<DateTime> get _dates => day == null || time == null
      ? []
      : List.generate(
          occurrences,
          (i) => DateTime(day!.year, day!.month, day!.day + i * 7, time!.hour,
              time!.minute));

  bool get _isValid {
    if (advisorId == null ||
        day == null ||
        time == null ||
        instructions.text.length > 500) {
      return false;
    }
    if (mode == 'online') {
      final uri = Uri.tryParse(meetingUrl.text.trim());
      return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          meetingUrl.text.trim().length <= 1000;
    }
    return instructions.text.trim().isNotEmpty;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 90)));
    if (picked != null && mounted) setState(() => day = picked);
  }

  Future<void> _submit() async {
    if (!_isValid || saving) return;
    final dates = _dates;
    final now = DateTime.now();
    if (dates.any((start) =>
        !start.isAfter(now) ||
        start.isAfter(now.add(const Duration(days: 90))))) {
      setState(() => error = 'اختر وقتًا مستقبليًا خلال 90 يومًا.');
      return;
    }
    if (dates.length > 1 &&
        !await showAppConfirmDialog(context,
            title: 'نشر مواعيد أسبوعية',
            scrollable: true,
            message:
                'سيتم نشر ${dates.length} مواعيد. لن يُنشر أي منها إذا تعارض أحدها مع موعد موجود.\n${dates.map((date) => _when(context, date.toIso8601String())).join('\n')}',
            confirmLabel: 'نشر المواعيد')) {
      return;
    }
    if (!mounted || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (dates.length > 1) {
        await ConsultationRepository.instance.publishSlots(
            advisorId: advisorId!,
            startsAt: dates,
            mode: mode,
            meetingUrl: mode == 'online' ? meetingUrl.text.trim() : '',
            instructions: instructions.text.trim());
      } else {
        await ConsultationRepository.instance.publishSlot(
          advisorId: advisorId!,
          startsAt: dates.single,
          mode: mode,
          meetingUrl: mode == 'online' ? meetingUrl.text.trim() : '',
          instructions: instructions.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is ApiException ? e.message : 'تعذر نشر الموعد.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    return AppScaffold(
      title: 'نشر موعد استشارة',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdmin) ...[
              const Text('المستشار', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: AppColors.border)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: advisorId,
                    hint: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('اختر مستشارًا')),
                    items: widget.advisors
                        .map((a) => DropdownMenuItem(
                            value: a['_id'] as String,
                            child: Text(a['name'] as String? ?? '—')))
                        .toList(),
                    onChanged: (v) => setState(() => advisorId = v),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('نوع الاستشارة', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Wrap(
                spacing: 8,
                children: _kModes.entries
                    .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: mode == e.key,
                        onSelected: (_) => setState(() => mode = e.key)))
                    .toList()),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
                initialValue: occurrences,
                decoration: const InputDecoration(labelText: 'تكرار أسبوعي'),
                items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(
                            i == 0 ? 'موعد واحد' : '${i + 1} مواعيد أسبوعية'))),
                onChanged: saving
                    ? null
                    : (value) => setState(() => occurrences = value!)),
            const SizedBox(height: 14),
            const Text('التاريخ', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            OutlinedButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today),
                label: Text(day == null
                    ? 'اختر تاريخًا'
                    : local.formatCompactDate(day!))),
            const SizedBox(height: 14),
            const Text('الوقت (كل 30 دقيقة)', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.border)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TimeOfDay>(
                  isExpanded: true,
                  value: time,
                  hint: const Padding(
                      padding: EdgeInsets.all(4), child: Text('اختر وقتًا')),
                  items: _halfHours
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(local.formatTimeOfDay(t,
                              alwaysUse24HourFormat: true))))
                      .toList(),
                  onChanged: (v) => setState(() => time = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (mode == 'online') ...[
              const Text('رابط الاجتماع (https)', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: AppColors.border)),
                child: TextField(
                    controller: meetingUrl,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'https://meet.example.com/xyz',
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12))),
              ),
            ] else ...[
              Text(
                  mode == 'phone'
                      ? 'تعليمات الاتصال الهاتفي'
                      : 'عنوان المكتب وتعليمات الوصول',
                  style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: AppColors.border)),
                child: TextField(
                    controller: instructions,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12))),
              ),
            ],
            if (_dates.length > 1) ...[
              const SizedBox(height: 14),
              const Text('المواعيد التي ستُنشر بتوقيت جهازك',
                  style: AppTextStyles.caption),
              for (final date in _dates)
                Text(_when(context, date.toIso8601String())),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
                label: saving ? 'جاري النشر...' : 'نشر الموعد',
                onPressed: saving || !_isValid ? null : _submit),
          ],
        ),
      ),
    );
  }
}
