import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/university_repository.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;
import '../applications_documents_payments/documents_screens.dart'
    show docStatusMeta, docTypeLabel;

const List<Map<String, dynamic>> kApplicationDetailedStatuses = [
  {'key': 'documents-missing', 'label': 'مستندات ناقصة', 'icon': Icons.folder_off_outlined, 'tone': 'warning'},
  {'key': 'ready-to-apply', 'label': 'جاهز للتقديم', 'icon': Icons.check_circle_outline, 'tone': 'info'},
  {'key': 'under-review', 'label': 'قيد المراجعة', 'icon': Icons.hourglass_top_rounded, 'tone': 'info'},
  {'key': 'additional-documents-required', 'label': 'مطلوب مستندات إضافية', 'icon': Icons.upload_file_outlined, 'tone': 'warning'},
  {'key': 'conditional-admission', 'label': 'قبول مبدئي', 'icon': Icons.verified_outlined, 'tone': 'success'},
  {'key': 'payment-required', 'label': 'الدفع مطلوب', 'icon': Icons.payment_outlined, 'tone': 'warning'},
  {'key': 'payment-verification', 'label': 'التحقق من الدفع', 'icon': Icons.receipt_long_outlined, 'tone': 'info'},
  {'key': 'final-admission', 'label': 'قبول نهائي', 'icon': Icons.school_rounded, 'tone': 'success'},
  {'key': 'visa-preparation', 'label': 'تجهيز التأشيرة', 'icon': Icons.flight_takeoff_rounded, 'tone': 'info'},
  {'key': 'completed', 'label': 'مكتمل', 'icon': Icons.task_alt_rounded, 'tone': 'success'},
  {'key': 'accepted', 'label': 'مقبول نهائيًا', 'icon': Icons.star_rounded, 'tone': 'success'},
  {'key': 'rejected', 'label': 'مرفوض', 'icon': Icons.cancel_outlined, 'tone': 'danger'},
];

Color _toneColor(String? tone) {
  switch (tone) {
    case 'success':
      return AppColors.success;
    case 'warning':
      return AppColors.warning;
    case 'danger':
      return AppColors.danger;
    default:
      return AppColors.info;
  }
}

class UniversityApplicationReviewScreen extends StatefulWidget {
  final String applicationId;
  final Map<String, dynamic> initialData;
  const UniversityApplicationReviewScreen(
      {super.key, required this.applicationId, required this.initialData});
  @override
  State<UniversityApplicationReviewScreen> createState() =>
      _UniversityApplicationReviewScreenState();
}

class _UniversityApplicationReviewScreenState
    extends State<UniversityApplicationReviewScreen> {
  late Map<String, dynamic> _app;
  bool _updating = false;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _app = widget.initialData;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await UniversityRepository.instance
          .getApplicationById(widget.applicationId);
      if (mounted) setState(() => _app = data);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _firstLoad = false);
    }
  }

  Future<void> _updateStatus(String detailedStatus, {String? note}) async {
    setState(() => _updating = true);
    try {
      final updated = await UniversityRepository.instance
          .updateApplicationStatus(widget.applicationId,
              detailedStatus: detailedStatus, note: note);
      if (!mounted) return;
      setState(() => _app = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم تحديث حالة الطلب'),
          backgroundColor: AppColors.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحديث الحالة'),
          backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showStatusSheet() {
    final currentKey = _app['detailedStatus'] as String? ?? _app['status'] as String?;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSheet(
        currentKey: currentKey,
        onSelect: (key) async {
          Navigator.pop(context);
          // Ask for note if status requires one
          String? note;
          if (key == 'additional-documents-required' ||
              key == 'conditional-admission' ||
              key == 'rejected') {
            note = await _askForNote(key);
            if (note == null) return; // cancelled
          }
          await _updateStatus(key, note: note?.isEmpty == true ? null : note);
        },
      ),
    );
  }

  Future<String?> _askForNote(String statusKey) async {
    final label = kApplicationDetailedStatuses
        .firstWhere((s) => s['key'] == statusKey,
            orElse: () => {'label': 'تحديث'})['label'] as String;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ملاحظة — $label'),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'أدخل ملاحظة للطالب (اختياري)...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('تأكيد')),
        ],
      ),
    );
  }

  Future<void> _requestDocument() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب مستند إضافي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'اكتب وصفًا للمستند المطلوب من الطالب:',
                style: AppTextStyles.caption),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText:
                      'مثال: يرجى رفع كشف درجات مصدّق من الجهة الرسمية'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, reasonCtrl.text.trim());
              },
              child: const Text('إرسال')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await UniversityRepository.instance
          .requestDocument(widget.applicationId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إرسال الطلب للطالب'),
            backgroundColor: AppColors.success));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر إرسال الطلب'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _app['student'] as Map<String, dynamic>?;
    final program = _app['program'] as Map<String, dynamic>?;
    final documents = _app['documents'] as List<dynamic>? ?? [];
    final timeline =
        _app['statusTimeline'] as List<dynamic>? ?? [];
    final meta = appStatusMeta(_app);
    final name = student?['name'] as String? ?? '—';
    final email = student?['email'] as String? ?? '';
    final programName = program?['title'] as String? ??
        program?['name'] as String? ??
        '—';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return AppScaffold(
      title: name,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.navy,
        child: _firstLoad
            ? const LoadingState(message: 'جاري التحميل...')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Student/Program Header ──────────────────────────────
                  _buildHeader(
                      initials, name, email, programName, meta),
                  const SizedBox(height: 16),

                  // ── Documents ──────────────────────────────────────────
                  const Text('المستندات المقدمة',
                      style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  _buildDocuments(documents),
                  const SizedBox(height: 16),

                  // ── Status Timeline ────────────────────────────────────
                  if (timeline.isNotEmpty) ...[
                    const Text('سجل التحديثات',
                        style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 10),
                    _buildTimeline(timeline),
                    const SizedBox(height: 16),
                  ],

                  // ── Actions ────────────────────────────────────────────
                  const Text('الإجراءات', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _updating
                        ? 'جاري التحديث...'
                        : 'تحديث حالة الطلب',
                    onPressed:
                        _updating ? null : _showStatusSheet,
                    icon: Icons.update_rounded,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _requestDocument,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('طلب مستند إضافي من الطالب'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: AppColors.border)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(String initials, String name, String email,
      String programName, dynamic meta) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    if (email.isNotEmpty)
                      Text(email,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              StatusBadge(label: meta.label, color: meta.color),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.school_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(programName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocuments(List<dynamic> documents) {
    if (documents.isEmpty) {
      return AppCard(
        child: Row(
          children: const [
            Icon(Icons.inbox_outlined,
                color: AppColors.textSecondary, size: 20),
            SizedBox(width: 10),
            Text('لم يرفع الطالب أي مستندات بعد.',
                style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        children: documents.asMap().entries.map((e) {
          final idx = e.key;
          final doc = e.value as Map<String, dynamic>;
          final docMeta = docStatusMeta(doc);
          return Column(
            children: [
              if (idx != 0) const Divider(height: 16),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 17,
                        color: AppColors.navy),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        docTypeLabel(doc['type'] as String?),
                        style: AppTextStyles.body),
                  ),
                  StatusBadge(
                      label: docMeta.label,
                      color: docMeta.color),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> timeline) {
    final items = timeline.reversed.take(5).toList();
    return AppCard(
      child: Column(
        children: items.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value as Map<String, dynamic>;
          final status = entry['status'] as String? ?? '';
          final statusMeta = kApplicationDetailedStatuses.firstWhere(
              (s) => s['key'] == status,
              orElse: () => {'label': status, 'tone': 'info'});
          final note = entry['note'] as String?;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (idx != 0) const Divider(height: 14),
              Row(
                children: [
                  Icon(Icons.circle,
                      size: 8,
                      color: _toneColor(statusMeta['tone'] as String?)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(statusMeta['label'] as String,
                        style: AppTextStyles.body),
                  ),
                ],
              ),
              if (note != null && note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 3),
                  child: Text(note,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Status Bottom Sheet ──────────────────────────────────────────────────────
class _StatusSheet extends StatelessWidget {
  final String? currentKey;
  final void Function(String key) onSelect;
  const _StatusSheet({required this.currentKey, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('اختر الحالة الجديدة',
                  style: AppTextStyles.screenTitle),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: kApplicationDetailedStatuses.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final s = kApplicationDetailedStatuses[i];
                final isCurrent = s['key'] == currentKey;
                final color = _toneColor(s['tone'] as String?);
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s['icon'] as IconData,
                        size: 18, color: color),
                  ),
                  title: Text(s['label'] as String,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isCurrent
                              ? AppColors.navy
                              : AppColors.textPrimary)),
                  trailing: isCurrent
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.navy, size: 18)
                      : null,
                  onTap: () => onSelect(s['key'] as String),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
