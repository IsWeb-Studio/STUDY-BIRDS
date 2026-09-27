import 'live_consultation_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/catalog_repository.dart';
import '../../core/notification_scheduler.dart';
import '../../core/analytics_service.dart';

class ServicesCenterScreen extends StatefulWidget {
  const ServicesCenterScreen({super.key});
  @override
  State<ServicesCenterScreen> createState() => _ServicesCenterScreenState();
}

class _ServicesCenterScreenState extends State<ServicesCenterScreen> {
  late Future<List<dynamic>> future = CatalogRepository.instance.getServices();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('services_center');
  }

  Future<void> refresh() async {
    final next = CatalogRepository.instance.getServices();
    setState(() => future = next);
    try {
      await next;
    } catch (_) {/* The FutureBuilder presents the retry state. */}
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'مركز الخدمات',
        body: FutureBuilder<List<dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1),
                itemCount: 6,
                itemBuilder: (_, __) => const SkeletonBox(
                    width: double.infinity, height: double.infinity,
                    borderRadius: 14),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                  message: 'تعذر تحميل الخدمات', onRetry: refresh);
            }
            final rows = (snapshot.data ?? []).whereType<Map>().toList();
            if (rows.isEmpty) {
              return const EmptyState(
                  icon: Icons.miscellaneous_services,
                  title: 'لا توجد خدمات متاحة',
                  message: 'ستظهر الخدمات التي ينشرها الفريق هنا.');
            }
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            return RefreshIndicator(
                onRefresh: refresh,
                color: AppColors.navy,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 152 + (scale > 1 ? (scale - 1) * 90 : 0)),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = Map<String, dynamic>.from(rows[index]);
                    final title = row['title']?.toString() ?? '';
                    return Semantics(
                        button: true,
                        label: title,
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ServiceDetailScreen(service: {
                                          ...row,
                                          'name': title,
                                          'price': 'يحدد بعد مراجعة الطلب',
                                        }))),
                            child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFFFEEDD),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Icon(_serviceIcon(title),
                                            size: 19, color: AppColors.orange)),
                                    const Spacer(),
                                    Text(title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body.copyWith(
                                            fontSize: 14,
                                            height: 1.5,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 16),
                                    const Text('السعر عند الطلب',
                                        style: AppTextStyles.caption),
                                  ],
                                )),
                          ),
                        ));
                  },
                ));
          },
        ),
      );
}

IconData _serviceIcon(String title) {
  final value = title.toLowerCase();
  if (value.contains('ترجم') || value.contains('translat')) {
    return Icons.translate_rounded;
  }
  if (value.contains('تصديق') ||
      value.contains('توثيق') ||
      value.contains('certif')) {
    return Icons.verified_rounded;
  }
  if (value.contains('تأمين') ||
      value.contains('تامين') ||
      value.contains('insur')) {
    return Icons.health_and_safety_rounded;
  }
  if (value.contains('مطار') ||
      value.contains('استقبال') ||
      value.contains('airport')) {
    return Icons.directions_car_filled_rounded;
  }
  if (value.contains('شريحة') ||
      value.contains('اتصال') ||
      value.contains('sim')) {
    return Icons.sim_card_rounded;
  }
  if (value.contains('بنك') ||
      value.contains('بنكي') ||
      value.contains('bank')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (value.contains('إقام') ||
      value.contains('اقام') ||
      value.contains('residen') ||
      value.contains('تأشير')) {
    return Icons.badge_rounded;
  }
  if (value.contains('سكن') || value.contains('housing')) {
    return Icons.apartment_rounded;
  }
  if (value.contains('جامع') ||
      value.contains('قبول') ||
      value.contains('دراس')) {
    return Icons.school_rounded;
  }
  return Icons.miscellaneous_services_rounded;
}

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _submitting = false;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestService() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'تأكيد طلب الخدمة',
      message: 'سيتم إرسال طلبك للفريق وستصلك إشعارات عند تحديث الحالة. متابعة؟',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final serviceId = widget.service['_id']?.toString() ?? '';
      await ApiClient.instance.post('/service-requests', body: {
        'serviceId': serviceId,
        'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم إرسال طلبك — تابع حالته من "طلباتي"'),
          backgroundColor: AppColors.success));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : 'تعذر إرسال الطلب، حاول مرة أخرى')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return AppScaffold(
      title: service['name'] as String? ?? service['title'] as String? ?? 'الخدمة',
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.list_alt_rounded, size: 18),
          label: const Text('طلباتي'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyServiceRequestsScreen())),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((service['detailBody'] as String? ?? '').isNotEmpty)
                    Text(
                        (service['detailBody'] as String).replaceAll(RegExp(r'<[^>]*>'), ''),
                        style: AppTextStyles.body),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                hintText: 'أي تفاصيل تريد إضافتها للفريق...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'بعد الإرسال سيتواصل معك فريق Study Birds لتحديد التفاصيل والدفع.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _submitting ? 'جاري الإرسال...' : 'طلب الخدمة',
              onPressed: _submitting ? null : _requestService,
            ),
          ],
        ),
      ),
    );
  }
}

// Tracks the student's own service requests with live status
class MyServiceRequestsScreen extends StatefulWidget {
  const MyServiceRequestsScreen({super.key});
  @override
  State<MyServiceRequestsScreen> createState() => _MyServiceRequestsScreenState();
}

class _MyServiceRequestsScreenState extends State<MyServiceRequestsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.get('/service-requests/mine').then((d) => d is List ? d : []);
  }

  Future<void> _refresh() async {
    setState(() => _future = ApiClient.instance.get('/service-requests/mine').then((d) => d is List ? d : []));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'طلبات الخدمات',
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErrorState(message: 'تعذر تحميل الطلبات', onRetry: _refresh);
          final rows = (snap.data ?? []).whereType<Map>().toList();
          if (rows.isEmpty) {
            return const EmptyState(icon: Icons.assignment_outlined, title: 'لا توجد طلبات بعد', message: 'اطلب خدمة من مركز الخدمات وستظهر هنا.');
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.navy,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = Map<String, dynamic>.from(rows[i]);
                final title = (r['serviceTitle'] as String?) ?? (r['service'] is Map ? r['service']['title'] : '') ?? '';
                final status = r['status'] as String? ?? 'pending';
                final assignedTo = r['assignedTo'] is Map ? r['assignedTo']['name'] as String? : null;
                final staffNote = r['staffNote'] as String? ?? '';
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700))),
                          _StatusChip(status),
                        ],
                      ),
                      if (assignedTo != null) ...[
                        const SizedBox(height: 6),
                        Text('الموظف المسؤول: $assignedTo', style: AppTextStyles.caption),
                      ],
                      if (staffNote.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('ملاحظة: $staffNote', style: AppTextStyles.caption.copyWith(color: AppColors.navy)),
                      ],
                      const SizedBox(height: 6),
                      Text(_formatDate(r['createdAt']), style: AppTextStyles.caption),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending'     => ('في الانتظار', Colors.orange),
      'assigned'    => ('تم التعيين', Colors.blue),
      'in-progress' => ('قيد التنفيذ', AppColors.navy),
      'completed'   => ('مكتمل', AppColors.success),
      'cancelled'   => ('ملغى', Colors.red),
      _             => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style:
                    AppTextStyles.body.copyWith(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class ConsultationBookingScreen extends StatelessWidget {
  final VoidCallback? onConfirm;
  const ConsultationBookingScreen({super.key, this.onConfirm});
  @override
  Widget build(BuildContext context) => LiveConsultationScreen(
        onBooked: onConfirm,
        onSlotBooked: (slot) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConsultationConfirmationScreen(slot: slot))),
      );
}

class ConsultationConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> slot;
  const ConsultationConfirmationScreen({super.key, required this.slot});

  @override
  State<ConsultationConfirmationScreen> createState() =>
      _ConsultationConfirmationScreenState();
}

class _ConsultationConfirmationScreenState
    extends State<ConsultationConfirmationScreen> {
  Map<String, dynamic> get slot => widget.slot;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.consultationBooked(
        '${slot['advisor']?['_id'] ?? slot['advisorId'] ?? 'unknown'}');
    _scheduleReminder();
  }

  void _scheduleReminder() {
    final id = '${slot['_id'] ?? slot['bookingId'] ?? ''}';
    final startsAt = DateTime.tryParse('${slot['startsAt'] ?? ''}');
    if (id.isEmpty || startsAt == null) return;
    NotificationScheduler.instance.scheduleConsultation(
      id: id,
      title: 'تذكير: استشارتك بعد ساعة',
      at: startsAt,
    );
  }

  String _formatDate(BuildContext ctx, dynamic raw) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) return '—';
    final local = MaterialLocalizations.of(ctx);
    return '${local.formatCompactDate(date)} — ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}';
  }

  Future<void> _openMeeting(BuildContext ctx, String raw) async {
    final uri = Uri.tryParse(raw);
    try {
      if (uri == null ||
          uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('تعذر فتح رابط الاجتماع.')));
      }
    }
  }

  Future<void> _addToGoogleCalendar(BuildContext ctx) async {
    final startsAt = DateTime.tryParse('${slot['startsAt'] ?? ''}');
    if (startsAt == null) return;
    final endsAt = startsAt.add(const Duration(minutes: 30));
    String fmt(DateTime d) =>
        d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]|\.\d+'), '');
    final advisor = '${slot['advisor']?['name'] ?? 'المستشار'}';
    final mode = kConsultationModes[slot['mode']] ?? '${slot['mode']}';
    final meetingUrl = '${slot['meetingUrl'] ?? ''}';
    final details = meetingUrl.startsWith('https://')
        ? 'استشارة $mode مع $advisor\nرابط الاجتماع: $meetingUrl'
        : 'استشارة $mode مع $advisor';

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'استشارة Study Birds مع $advisor',
      'dates': '${fmt(startsAt)}/${fmt(endsAt)}',
      'details': details,
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تطبيق التقويم.')));
      }
    }
  }

  Future<void> _addToAppleCalendar(BuildContext ctx) async {
    final bookingId = '${slot['_id'] ?? slot['bookingId'] ?? ''}';
    if (bookingId.isEmpty) return;
    // Download .ics from server and open with the system handler (iOS opens in Calendar)
    final icsUri = Uri.parse('${ApiClient.baseUrl}/consultations/bookings/$bookingId/ics');
    try {
      if (!await launchUrl(icsUri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل ملف التقويم.')));
      }
    }
  }

  Future<void> _showCalendarOptions(BuildContext ctx) async {
    await showModalBottomSheet<void>(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('أضف للتقويم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Color(0xFF4285F4)),
                title: const Text('Google Calendar'),
                onTap: () { Navigator.pop(ctx); _addToGoogleCalendar(ctx); },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.black87),
                title: const Text('Apple Calendar / iCal'),
                onTap: () { Navigator.pop(ctx); _addToAppleCalendar(ctx); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingUrl = '${slot['meetingUrl'] ?? ''}';
    final hasUrl = slot['mode'] == 'online' && meetingUrl.startsWith('https://');
    return AppScaffold(
      title: 'تأكيد الموعد',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 42),
            ),
            const SizedBox(height: 16),
            const Text('تم تأكيد موعدك بنجاح', style: AppTextStyles.cardTitle),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                children: [
                  _Row(
                      label: 'التاريخ والوقت',
                      value: _formatDate(context, slot['startsAt'])),
                  const Divider(height: 20),
                  _Row(
                      label: 'نوع الاستشارة',
                      value:
                          kConsultationModes[slot['mode']] ?? '${slot['mode']}'),
                  const Divider(height: 20),
                  _Row(
                      label: 'المستشار',
                      value: '${slot['advisor']?['name'] ?? '—'}'),
                  if (hasUrl) ...[
                    const Divider(height: 20),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('رابط الاجتماع',
                              style: AppTextStyles.caption),
                          TextButton.icon(
                              onPressed: () =>
                                  _openMeeting(context, meetingUrl),
                              icon: const Icon(Icons.video_call, size: 18),
                              label: const Text('فتح')),
                        ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('سيتم إرسال تذكير لك قبل الموعد.',
                style: AppTextStyles.caption),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.navy),
              label: const Text('أضف للتقويم', style: TextStyle(color: AppColors.navy)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: AppColors.navy),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              onPressed: () => _showCalendarOptions(context),
            ),
          ],
        ),
      ),
    );
  }
}
