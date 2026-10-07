import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/auth_session.dart';
import 'application_documents_screen.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/status_info.dart';
import '../../core/services/analytics_service.dart';
import 'application_card_view.dart';
import '../../core/repositories/student_repository.dart';
import '../../core/services/realtime_sync_service.dart';
import '../services_support/messaging_and_emergency_screens.dart'
    show ConversationThreadScreen;
import 'documents_screens.dart'
    show docStatusMeta, docTypeLabel, DocumentDetailScreen;
import '../universities_programs_countries/explore_hub_screen.dart';

/// Maps the backend's application status (legacy 5-value `status`, or the
/// richer 14-value `detailedStatus` when present) to Arabic label + color.
class AppStatusMeta {
  final String label;
  final Color color;
  const AppStatusMeta(this.label, this.color);
}

AppStatusMeta appStatusMeta(Map<String, dynamic> app) {
  // The server's plain-language copy wins; the switch below is the fallback
  // for older servers and for timeline entries, which carry only a code.
  final info = StatusInfo.of(app);
  if (info != null) return AppStatusMeta(info.label, info.color);
  final detailed = app['detailedStatus'] as String?;
  switch (detailed ?? app['status'] as String? ?? 'draft') {
    case 'draft':
      return const AppStatusMeta('مسودة', AppColors.neutral);
    case 'documents-missing':
      return const AppStatusMeta('مستندات ناقصة', AppColors.warning);
    case 'ready-to-apply':
      return const AppStatusMeta('جاهز للتقديم', AppColors.info);
    case 'submitted':
      return const AppStatusMeta('تم التقديم', AppColors.info);
    case 'under-review':
      return const AppStatusMeta('قيد المراجعة من الجامعة', AppColors.info);
    case 'additional-documents-required':
      return const AppStatusMeta('مطلوب مستندات إضافية', AppColors.warning);
    case 'conditional-admission':
      return const AppStatusMeta('قبول مشروط', AppColors.orange);
    case 'payment-required':
      return const AppStatusMeta('الدفع مطلوب', AppColors.warning);
    case 'payment-verification':
      return const AppStatusMeta('التحقق من الدفع', AppColors.info);
    case 'final-admission':
      return const AppStatusMeta('قبول نهائي', AppColors.success);
    case 'visa-preparation':
      return const AppStatusMeta('تجهيز التأشيرة', AppColors.orange);
    case 'completed':
    case 'file-completed-accepted':
      return const AppStatusMeta('مكتمل', AppColors.success);
    case 'accepted':
      return const AppStatusMeta('مقبول', AppColors.success);
    // Website review actions, as they appear in the status timeline.
    case 'preliminary-accepted':
      return const AppStatusMeta('قبول مبدئي', AppColors.orange);
    case 'preliminary-accepted-first-payment':
      return const AppStatusMeta('الدفع مطلوب', AppColors.warning);
    case 'final-accepted':
      return const AppStatusMeta('قبول نهائي', AppColors.success);
    case 'rejected':
    case 'file-completed-rejected':
      return const AppStatusMeta('غير مقبول', AppColors.danger);
    default:
      return const AppStatusMeta('قيد المراجعة', AppColors.info);
  }
}

class ApplicationsListScreen extends StatefulWidget {
  const ApplicationsListScreen({super.key});

  @override
  State<ApplicationsListScreen> createState() => _ApplicationsListScreenState();
}

class _ApplicationsListScreenState extends State<ApplicationsListScreen> {
  List<dynamic> _apps = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<DateTime>? _syncSub;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('applications');
    _load();
    _syncSub = RealtimeSyncService.instance.onTick.listen((_) {
      StudentRepository.instance
          .getApplications(forceRefresh: true)
          .then((data) { if (mounted) setState(() => _apps = data); })
          .catchError((_) {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await StudentRepository.instance.getApplications();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل طلباتك، تحقق من الاتصال وحاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'طلباتي',
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _apps.isEmpty
                  ? EmptyState(
                      icon: Icons.description_outlined,
                      title: 'لا توجد طلبات بعد',
                      message: 'ابدأ رحلتك بتقديم طلبك الأول لجامعة تناسبك.',
                      ctaLabel: 'استكشف الجامعات',
                      onCta: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ExploreHubScreen())),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.navy,
                      child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _apps.length,
                      itemBuilder: (context, i) {
                        final a = _apps[i] as Map<String, dynamic>;
                        final program = a['program'] as Map<String, dynamic>?;
                        final university =
                            program?['university'] as Map<String, dynamic>?;
                        final country =
                            university?['country'] as Map<String, dynamic>?;
                        final meta = appStatusMeta(a);

                        return AppCard(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ApplicationDetailScreen(application: a))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                      child: Text(
                                          university?['name'] as String? ??
                                              'جامعة غير معروفة',
                                          style: AppTextStyles.cardTitle)),
                                  StatusBadge(
                                      label: meta.label, color: meta.color),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${program?['title'] ?? '—'} — ${country?['name'] ?? ''}',
                                style: AppTextStyles.caption,
                              ),
                              if (ApplicationCardFacts.of(a) case final card?)
                                ApplicationCardFacts(card: card, compact: true),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
    );
  }
}

class ApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  int _tab = 0;
  Map<String, dynamic>? _updatedApplication;
  static const _tabs = ['نظرة عامة', 'المستندات', 'الجدول الزمني'];

  @override
  Widget build(BuildContext context) {
    final a = _updatedApplication ?? widget.application;
    final program = a['program'] as Map<String, dynamic>?;
    final university = program?['university'] as Map<String, dynamic>?;
    final country = university?['country'] as Map<String, dynamic>?;
    final documents = a['documents'] as List<dynamic>? ?? [];
    final timeline = a['statusTimeline'] as List<dynamic>? ?? [];
    final meta = appStatusMeta(a);

    return AppScaffold(
      title: 'تفاصيل الطلب',
      actions: [
        if (AuthSession.instance.currentUser?.role == UserRole.student)
          IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              tooltip: 'استكمال مستندات الطلب',
              onPressed: () async {
                final updated = await Navigator.of(context)
                    .push<Map<String, dynamic>>(MaterialPageRoute(
                        builder: (_) => ApplicationDocumentsScreen(
                            applicationId: a['_id'] as String)));
                if (updated != null && mounted)
                  setState(() {
                    _updatedApplication = updated;
                  });
              }),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white),
          tooltip: 'مراسلة الفريق',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ConversationThreadScreen())),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_rounded,
                            color: AppColors.navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(university?['name'] as String? ?? '—',
                                style: AppTextStyles.cardTitle),
                            Text(program?['title'] as String? ?? '—',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                          label: 'الدولة',
                          value: country?['name'] as String? ?? '—'),
                      _InfoChip(
                          label: 'المدينة',
                          value: university?['city'] as String? ?? '—'),
                      _InfoChip(
                          label: 'الدرجة',
                          value: program?['degreeLevel'] as String? ?? '—'),
                      _InfoChip(
                          label: 'اللغة',
                          value: program?['language'] as String? ?? '—'),
                      _InfoChip(
                          label: 'الفصل',
                          value: program?['intake'] as String? ?? '—'),
                    ],
                  ),
                  if (StatusInfo.of(a) != null) ...[
                    const SizedBox(height: 12),
                    StatusExplanationCard(info: StatusInfo.of(a)!),
                  ],
                  // Admission, documents, payment, visa, consultant (PRD 16).
                  if (ApplicationCardFacts.of(a) case final card?)
                    ApplicationCardFacts(card: card),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _tabs.length,
              itemBuilder: (context, i) {
                final selected = i == _tab;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navy : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                          color: selected ? AppColors.navy : AppColors.border),
                    ),
                    child: Text(_tabs[i],
                        style: TextStyle(
                            color:
                                selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(_tab, a, meta, documents, timeline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tab, Map<String, dynamic> a, AppStatusMeta meta,
      List<dynamic> documents, List<dynamic> timeline) {
    switch (tab) {
      case 1: // Documents
        if (documents.isEmpty) {
          return const AppCard(
              child: Text('لم يتم إرفاق مستندات لهذا الطلب بعد.',
                  style: AppTextStyles.body));
        }
        return Column(
          children: documents.map((d) {
            final doc = d as Map<String, dynamic>;
            final docMeta = docStatusMeta(doc);
            return AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(document: doc))),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      color: AppColors.navy, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(docTypeLabel(doc['type'] as String?),
                          style: AppTextStyles.cardTitle)),
                  StatusBadge(label: docMeta.label, color: docMeta.color),
                ],
              ),
            );
          }).toList(),
        );
      case 2: // Timeline
        if (timeline.isEmpty) {
          return const AppCard(
              child: Text('لا يوجد سجل أحداث بعد.', style: AppTextStyles.body));
        }
        return Column(
          children: timeline.reversed.map((t) {
            final entry = t as Map<String, dynamic>;
            return AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appStatusMeta({'status': entry['status']}).label,
                            style: AppTextStyles.cardTitle),
                        if ((entry['note'] as String?)?.isNotEmpty == true)
                          Text(entry['note'] as String,
                              style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      case 0:
      default: // Overview
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                StatusBadge(label: meta.label, color: meta.color)
              ]),
              const SizedBox(height: 12),
              const Text('ملاحظات', style: AppTextStyles.sectionLabel),
              const SizedBox(height: 6),
              Text(
                (a['notes'] as String?)?.isNotEmpty == true
                    ? a['notes'] as String
                    : 'لا توجد ملاحظات إضافية على هذا الطلب حاليًا.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        );
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
