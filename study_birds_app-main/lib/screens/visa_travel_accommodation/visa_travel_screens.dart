import 'arrival_services_screen.dart';
import 'package:flutter/material.dart';
import '../../core/utils/document_access.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/student_repository.dart';
import '../../core/repositories/catalog_repository.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/services/analytics_service.dart';

// ── Pure helpers (extracted for testability) ───────────────────────────────

/// Maps a backend journey-stage key to a 0-5 visa sub-step index.
///
/// Visa sub-steps:
///  0 – لم تبدأ (before preliminary acceptance)
///  1 – التحضير (preliminary-accepted → first-payment)
///  2 – إعداد المستندات (final-accepted)
///  3 – تم التقديم (at visa stage)
///  4 – قيد المراجعة (still at visa, alias used for display)
///  5 – تمت الموافقة (travel or beyond)
int visaStepFromJourneyStage(String stage) {
  final idx = kJourneyStageOrder.indexWhere((s) => s['key'] == stage);
  if (idx < 0) return 0;
  if (idx < 5) return 0;
  if (idx < 7) return 1;
  if (idx < 8) return 2;
  if (idx == 8) return 3; // 'visa'
  return 5;
}

/// Returns [label, color] badge for the visa status derived from [stage].
({String label, Color color}) visaBadgeFromJourneyStage(String stage) {
  final idx = kJourneyStageOrder.indexWhere((s) => s['key'] == stage);
  if (idx < 0 || idx < 5) {
    return (label: 'لم تبدأ', color: AppColors.neutral);
  }
  if (idx < 7) return (label: 'التحضير', color: AppColors.info);
  if (idx < 8) return (label: 'إعداد المستندات', color: AppColors.warning);
  if (idx == 8) return (label: 'قيد المعالجة', color: AppColors.orange);
  return (label: 'تمت الموافقة', color: AppColors.success);
}

// ── Visa requirements list ─────────────────────────────────────────────────

/// Standard visa requirements mapped to document-type keys the backend knows.
/// A requirement is "done" when the student has uploaded a doc of that type.
const List<({String docKey, String label})> kVisaRequirements = [
  (docKey: 'passport', label: 'جواز السفر'),
  (docKey: 'biometric-photo', label: 'صورة شخصية'),
  (docKey: 'latest-qualification', label: 'آخر مؤهل دراسي'),
  (docKey: 'language-certificate', label: 'شهادة اللغة (إن وُجدت)'),
];

// ── VisaCenterScreen ───────────────────────────────────────────────────────

class VisaCenterScreen extends StatefulWidget {
  const VisaCenterScreen({super.key});

  @override
  State<VisaCenterScreen> createState() => _VisaCenterScreenState();
}

class _VisaCenterScreenState extends State<VisaCenterScreen> {
  bool _loading = true;
  String? _error;
  String _currentStage = '';
  Set<String> _uploadedDocKeys = {};
  List<({String docKey, String label})> _requirements = kVisaRequirements;
  Map<String, dynamic>? _countryData;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('visa_center');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        StudentRepository.instance.getOverview(),
        StudentRepository.instance.getDocuments(),
        StudentRepository.instance.getProfile(),
        CatalogRepository.instance.getCountries(),
      ]);
      final overview = results[0] as DashboardOverview;
      final docs = results[1] as List<dynamic>;
      final profile = results[2] as Map<String, dynamic>?;
      final countries = results[3] as List<dynamic>;

      final targetCountries = (profile?['targetCountries'] as List?)?.cast<String>() ?? [];
      Map<String, dynamic>? matchedCountry;
      if (targetCountries.isNotEmpty) {
        final target = targetCountries.first.toLowerCase();
        for (final c in countries) {
          final map = c as Map<String, dynamic>;
          final name = (map['name'] as String? ?? '').toLowerCase();
          final slug = (map['slug'] as String? ?? '').toLowerCase();
          if (name == target || slug == target || name.contains(target) || target.contains(name)) {
            matchedCountry = map;
            break;
          }
        }
      }

      List<({String docKey, String label})> reqs = kVisaRequirements;
      if (matchedCountry != null) {
        final raw = matchedCountry['visaRequirements'] as List?;
        if (raw != null && raw.isNotEmpty) {
          reqs = raw
              .cast<Map>()
              .map((r) => (
                    docKey: r['docKey']?.toString() ?? '',
                    label: r['label']?.toString() ?? '',
                  ))
              .where((r) => r.docKey.isNotEmpty)
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _currentStage = overview.currentStage;
        _uploadedDocKeys =
            docs.map((d) => (d as Map)['type']?.toString() ?? '').toSet();
        _requirements = reqs;
        _countryData = matchedCountry;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات التأشيرة. تحقق من الإنترنت وحاول مجدداً.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppScaffold(title: 'مركز التأشيرة', body: LoadingState(message: 'جاري التحميل...'));
    if (_error != null) {
      return AppScaffold(
        title: 'مركز التأشيرة',
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final badge = visaBadgeFromJourneyStage(_currentStage);
    final stageLabel = kJourneyStageOrder
        .firstWhere((s) => s['key'] == _currentStage,
            orElse: () => {'title': _currentStage})['title'] ??
        _currentStage;

    final countryName = _countryData?['name'] as String?;
    final processingDays = (_countryData?['processingDays'] as num?)?.toInt() ?? 0;
    final visaFeeUsd = (_countryData?['visaFeeUsd'] as num?)?.toInt() ?? 0;
    final langReqs = (_countryData?['languageRequirements'] as List?)?.cast<String>() ?? [];
    final notesList = (_countryData?['visaNotesList'] as List?)?.cast<String>() ?? [];

    return AppScaffold(
      title: 'مركز التأشيرة',
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh))
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(label: badge.label, color: badge.color),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: AppColors.navy, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المرحلة الحالية', style: AppTextStyles.caption),
                      Text(stageLabel, style: AppTextStyles.cardTitle),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (countryName != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.flag_rounded, color: AppColors.navy, size: 18),
                    const SizedBox(width: 8),
                    Text(countryName, style: AppTextStyles.cardTitle),
                  ]),
                  if (processingDays > 0 || visaFeeUsd > 0) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (processingDays > 0) ...[
                        const Icon(Icons.schedule_rounded, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$processingDays يوم معالجة', style: AppTextStyles.caption),
                        const SizedBox(width: 16),
                      ],
                      if (visaFeeUsd > 0) ...[
                        const Icon(Icons.attach_money_rounded, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$visaFeeUsd \$', style: AppTextStyles.caption),
                      ],
                    ]),
                  ],
                  if (langReqs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text('متطلبات اللغة', style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    ...langReqs.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.translate_rounded, size: 14, color: AppColors.info),
                        const SizedBox(width: 6),
                        Expanded(child: Text(r, style: AppTextStyles.body)),
                      ]),
                    )),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('المستندات المطلوبة للتأشيرة', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: _requirements
                  .map((req) {
                    final done = _uploadedDocKeys.contains(req.docKey);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: done ? AppColors.success : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(req.label, style: AppTextStyles.body)),
                          if (!done)
                            Text('لم يُرفع', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          if (notesList.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملاحظات التأشيرة', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 8),
                  ...notesList.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.info),
                      const SizedBox(width: 6),
                      Expanded(child: Text(note, style: AppTextStyles.body)),
                    ]),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const InlineNotice(
              'الموعد الدقيق لمقابلة القنصلية يُحدَّد من قِبل فريق Study Birds وسيتم إبلاغك عبر الإشعارات.'),
        ],
        ),
      ),
    );
  }
}

// ── VisaStepsScreen ────────────────────────────────────────────────────────

const List<String> _visaStages = [
  'لم تبدأ',
  'التحضير',
  'إعداد المستندات',
  'تم التقديم',
  'قيد المراجعة',
  'تمت الموافقة',
];

class VisaStepsScreen extends StatefulWidget {
  const VisaStepsScreen({super.key});

  @override
  State<VisaStepsScreen> createState() => _VisaStepsScreenState();
}

class _VisaStepsScreenState extends State<VisaStepsScreen> {
  bool _loading = true;
  String? _error;
  int _currentStep = 0;

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
      final overview = await StudentRepository.instance.getOverview();
      if (!mounted) return;
      setState(() {
        _currentStep = visaStepFromJourneyStage(overview.currentStage);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل مراحل التأشيرة.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return AppScaffold(title: 'مراحل التأشيرة', body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12), child: SkeletonCard())));
    if (_error != null) {
      return AppScaffold(
        title: 'مراحل التأشيرة',
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: 'مراحل التأشيرة',
      actions: [
        IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _visaStages.length,
          itemBuilder: (context, i) {
            final done = i < _currentStep;
            final active = i == _currentStep;
            final isLast = i == _visaStages.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.success
                            : (active ? AppColors.orange : Colors.white),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: done
                                ? AppColors.success
                                : (active ? AppColors.orange : AppColors.border),
                            width: 2),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                          : (active
                              ? const Icon(Icons.circle, size: 8, color: Colors.white)
                              : null),
                    ),
                    if (!isLast)
                      Expanded(
                          child: Container(
                              width: 2,
                              color: done ? AppColors.success : AppColors.border)),
                  ],
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28, top: 4),
                  child: Text(
                    _visaStages[i],
                    style: active
                        ? AppTextStyles.cardTitle.copyWith(color: AppColors.orange)
                        : AppTextStyles.body,
                  ),
                ),
              ],
            ),
          );
          },
        ),
      ),
    );
  }
}

// ── TravelCenterScreen + AirportPickup analytics wired in initState ──────────

class TravelCenterScreen extends StatefulWidget {
  const TravelCenterScreen({super.key});

  @override
  State<TravelCenterScreen> createState() => _TravelCenterScreenState();
}

class _TravelCenterScreenState extends State<TravelCenterScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('travel_center');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await StudentRepository.instance.getArrivalServices();
      if (!mounted) return;
      setState(() {
        _data = list.isNotEmpty ? list.first as Map<String, dynamic>? : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات السفر.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppScaffold(title: 'مركز السفر', body: LoadingState(message: 'جاري التحميل...'));
    if (_error != null) {
      return AppScaffold(
        title: 'مركز السفر',
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: 'مركز السفر',
      actions: [
        IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_data == null) ...[
              const EmptyState(
                icon: Icons.flight_outlined,
                title: 'لم تُقدَّم بيانات السفر بعد',
                message: 'أضف معلومات رحلتك وطلب الخدمات عبر الزر أدناه.',
              ),
            ] else ...[
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.navy),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تاريخ السفر', style: AppTextStyles.caption),
                        Text(
                          _data!['arrivalDate'] != null
                              ? (_data!['arrivalDate'] as String).split('T').first
                              : 'غير محدد',
                          style: AppTextStyles.cardTitle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('معلومات الرحلة', style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 10),
                    _KV(label: 'رقم الرحلة', value: _data!['flightNumber']?.toString() ?? 'غير محدد'),
                    const SizedBox(height: 6),
                    _KV(label: 'وقت الوصول', value: _data!['arrivalTime']?.toString() ?? 'غير محدد'),
                    const SizedBox(height: 6),
                    _KV(label: 'المطار', value: _data!['airport']?.toString() ?? 'غير محدد'),
                    const SizedBox(height: 6),
                    _KV(label: 'حالة الطلب', value: _data!['status']?.toString() ?? 'submitted'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            PrimaryButton(
              label: _data == null ? 'تقديم بيانات السفر' : 'تعديل البيانات',
              onPressed: () async {
                await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ArrivalServicesScreen()));
                if (mounted) _load();
              },
              icon: Icons.flight_takeoff_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── AirportPickupScreen ────────────────────────────────────────────────────

class AirportPickupScreen extends StatefulWidget {
  const AirportPickupScreen({super.key});

  @override
  State<AirportPickupScreen> createState() => _AirportPickupScreenState();
}

class _AirportPickupScreenState extends State<AirportPickupScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

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
      final list = await StudentRepository.instance.getArrivalServices();
      if (!mounted) return;
      setState(() {
        _data = list.isNotEmpty ? list.first as Map<String, dynamic>? : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات الاستقبال.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return AppScaffold(title: 'استقبال المطار', body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12), child: SkeletonCard())));
    if (_error != null) {
      return AppScaffold(
        title: 'استقبال المطار',
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final services = (_data?['services'] as Map?)?.cast<String, dynamic>() ?? {};
    final pickupRequested = services['airportPickup'] == true;
    final status = _data?['status']?.toString() ?? '';

    return AppScaffold(
      title: 'استقبال المطار',
      actions: [
        IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_data == null || !pickupRequested) ...[
              const EmptyState(
                icon: Icons.local_taxi_rounded,
                title: 'لم يُطلب استقبال من المطار',
                message: 'يمكنك طلب خدمة الاستقبال عند تقديم بيانات وصولك.',
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'تقديم طلب الاستقبال',
                onPressed: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArrivalServicesScreen()));
                  if (mounted) _load();
                },
                icon: Icons.add_rounded,
              ),
            ] else ...[
              AppCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الحالة', style: AppTextStyles.caption),
                        StatusBadge(
                          label: _statusLabel(status),
                          color: _statusColor(status),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _KV(
                      label: 'موعد الوصول',
                      value: _data!['arrivalDate'] != null
                          ? (_data!['arrivalDate'] as String).split('T').first +
                              (_data!['arrivalTime'] != null
                                  ? ' - ${_data!['arrivalTime']}'
                                  : '')
                          : 'غير محدد',
                    ),
                    const SizedBox(height: 6),
                    _KV(label: 'رقم الرحلة', value: _data!['flightNumber']?.toString() ?? 'غير محدد'),
                    const SizedBox(height: 6),
                    _KV(label: 'المطار', value: _data!['airport']?.toString() ?? 'غير محدد'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const InlineNotice(
                  'سيتواصل معك فريق Study Birds لتأكيد تفاصيل الاستقبال قبل موعد وصولك.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArrivalServicesScreen()));
                  if (mounted) _load();
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('تعديل بيانات الوصول'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'تم التأكيد';
      case 'assigned':
        return 'تم تعيين السائق';
      case 'completed':
        return 'مكتمل';
      default:
        return 'تم الاستلام';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'assigned':
        return AppColors.success;
      case 'completed':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }
}

// ── Shared widget ──────────────────────────────────────────────────────────

class _KV extends StatelessWidget {
  final String label;
  final String value;
  const _KV({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      );
}

// ─── بند 42: التأمين الصحي ───────────────────────────────────────────────────

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});
  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await StudentRepository.instance.getInsurance();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'تعذر تحميل بيانات التأمين.'; _loading = false; });
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'active': return 'ساري';
      case 'expired': return 'منتهي';
      default: return 'في الانتظار';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'active': return AppColors.success;
      case 'expired': return AppColors.danger;
      default: return AppColors.warning;
    }
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'التأمين الصحي',
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.navy,
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : _data == null
                      ? const EmptyState(
                          icon: Icons.health_and_safety_outlined,
                          title: 'لا تتوفر بيانات التأمين بعد',
                          message: 'سيقوم الفريق بإضافة تفاصيل وثيقة تأمينك الصحي هنا.')
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          children: [
                            _InsuranceStatusCard(data: _data!, statusLabel: _statusLabel(_data!['status'] as String?), statusColor: _statusColor(_data!['status'] as String?)),
                            const SizedBox(height: 16),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('تفاصيل الوثيقة', style: AppTextStyles.sectionLabel),
                                  const SizedBox(height: 12),
                                  _InfoRow('مزود التأمين', _data!['provider']?.toString() ?? '—'),
                                  const Divider(height: 20),
                                  _InfoRow('رقم الوثيقة', _data!['policyNumber']?.toString() ?? '—'),
                                  const Divider(height: 20),
                                  _InfoRow('نطاق التغطية', _data!['coverage']?.toString() ?? '—'),
                                  const Divider(height: 20),
                                  _InfoRow('تاريخ البداية', _fmtDate(_data!['startDate'])),
                                  const Divider(height: 20),
                                  _InfoRow('تاريخ الانتهاء', _fmtDate(_data!['endDate'])),
                                ],
                              ),
                            ),
                            if ((_data!['notes'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              AppCard(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('ملاحظات', style: AppTextStyles.sectionLabel),
                                  const SizedBox(height: 8),
                                  Text(_data!['notes'] as String, style: AppTextStyles.body),
                                ]),
                              ),
                            ],
                            if ((_data!['cardFileUrl'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 16),
                              PrimaryButton(
                                onPressed: () async {
                                  final url = await resolveDocumentDownload(_data!['cardFileUrl'] as String);
                                  if (url != null && !await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تعذر فتح بطاقة التأمين.')));
                                    }
                                  }
                                },
                                label: 'تحميل بطاقة التأمين',
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
        ),
      );
}

class _InsuranceStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String statusLabel;
  final Color statusColor;
  const _InsuranceStatusCard({required this.data, required this.statusLabel, required this.statusColor});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.health_and_safety_rounded, color: AppColors.success, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('التأمين الصحي', style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: 16),
          Flexible(child: Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
        ],
      );
}

// ─── بند 43: معادلة الشهادة ──────────────────────────────────────────────────

class EquivalencyScreen extends StatefulWidget {
  const EquivalencyScreen({super.key});
  @override
  State<EquivalencyScreen> createState() => _EquivalencyScreenState();
}

class _EquivalencyScreenState extends State<EquivalencyScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await StudentRepository.instance.getEquivalency();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'تعذر تحميل بيانات المعادلة.'; _loading = false; });
    }
  }

  static const _statusLabels = <String, String>{
    'not-started': 'لم تبدأ بعد',
    'documents-collected': 'تم جمع المستندات',
    'submitted': 'مقدّم',
    'under-review': 'قيد المراجعة',
    'completed': 'مكتمل',
    'rejected': 'مرفوض',
  };

  static const _statusColors = <String, Color>{
    'not-started': AppColors.textSecondary,
    'documents-collected': AppColors.info,
    'submitted': AppColors.navy,
    'under-review': AppColors.warning,
    'completed': AppColors.success,
    'rejected': AppColors.danger,
  };

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _data?['status'] as String? ?? 'not-started';
    final statusLabel = _statusLabels[status] ?? status;
    final statusColor = _statusColors[status] ?? AppColors.textSecondary;
    final docs = (_data?['requiredDocuments'] as List?)?.cast<String>() ?? [];

    return AppScaffold(
      title: 'معادلة الشهادة',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _data == null
                    ? const EmptyState(
                        icon: Icons.verified_outlined,
                        title: 'لا تتوفر بيانات المعادلة بعد',
                        message: 'سيقوم الفريق بإضافة تفاصيل إجراءات معادلة شهادتك هنا.')
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        children: [
                          AppCard(
                            child: Row(children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.verified_rounded, color: statusColor, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('معادلة الشهادة', style: AppTextStyles.cardTitle),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(statusLabel,
                                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ])),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          AppCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('تفاصيل الطلب', style: AppTextStyles.sectionLabel),
                              const SizedBox(height: 12),
                              _InfoRow('الجهة المختصة', _data!['authority']?.toString() ?? '—'),
                              const Divider(height: 20),
                              _InfoRow('رقم الطلب', _data!['applicationNumber']?.toString() ?? '—'),
                              const Divider(height: 20),
                              _InfoRow('تاريخ التقديم', _fmtDate(_data!['submittedAt'])),
                              const Divider(height: 20),
                              _InfoRow('الموعد المتوقع للانتهاء', _fmtDate(_data!['expectedCompletionDate'])),
                              const Divider(height: 20),
                              _InfoRow('الرسوم', _data!['fees']?.toString() ?? '—'),
                            ]),
                          ),
                          if (docs.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            AppCard(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('المستندات المطلوبة', style: AppTextStyles.sectionLabel),
                                const SizedBox(height: 10),
                                for (final doc in docs)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(children: [
                                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.navy, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(doc, style: AppTextStyles.body)),
                                    ]),
                                  ),
                              ]),
                            ),
                          ],
                          if ((_data!['notes'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            AppCard(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('ملاحظات', style: AppTextStyles.sectionLabel),
                                const SizedBox(height: 8),
                                Text(_data!['notes'] as String, style: AppTextStyles.body),
                              ]),
                            ),
                          ],
                          if ((_data!['resultFileUrl'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 16),
                            PrimaryButton(
                              onPressed: () async {
                                final url = await resolveDocumentDownload(_data!['resultFileUrl'] as String);
                                if (url != null && !await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تعذر فتح الملف.')));
                                  }
                                }
                              },
                              label: 'تحميل وثيقة المعادلة',
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
      ),
    );
  }
}
