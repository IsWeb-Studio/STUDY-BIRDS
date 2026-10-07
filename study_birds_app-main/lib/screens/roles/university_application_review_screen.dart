import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/university_repository.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;
import '../applications_documents_payments/documents_screens.dart'
    show docStatusMeta, docTypeLabel;

const List<Map<String, dynamic>> kApplicationDetailedStatuses = [
  {'key': 'documents-missing',              'label': 'مستندات ناقصة',             'icon': Icons.folder_off_outlined,      'tone': 'warning', 'requireNote': true},
  {'key': 'ready-to-apply',                 'label': 'جاهز للتقديم',              'icon': Icons.check_circle_outline,     'tone': 'info',    'requireNote': false},
  {'key': 'under-review',                   'label': 'قيد المراجعة',              'icon': Icons.hourglass_top_rounded,    'tone': 'info',    'requireNote': false},
  {'key': 'additional-documents-required',  'label': 'مطلوب مستندات إضافية',     'icon': Icons.upload_file_outlined,     'tone': 'warning', 'requireNote': false},
  {'key': 'conditional-admission',          'label': 'قبول مبدئي',                'icon': Icons.verified_outlined,        'tone': 'success', 'requireNote': false},
  {'key': 'payment-required',               'label': 'الدفع مطلوب',               'icon': Icons.payment_outlined,         'tone': 'warning', 'requireNote': false},
  {'key': 'payment-verification',           'label': 'التحقق من الدفع',           'icon': Icons.receipt_long_outlined,    'tone': 'info',    'requireNote': false},
  {'key': 'final-admission',                'label': 'قبول نهائي',                'icon': Icons.school_rounded,           'tone': 'success', 'requireNote': false},
  {'key': 'visa-preparation',               'label': 'تجهيز التأشيرة',            'icon': Icons.flight_takeoff_rounded,   'tone': 'info',    'requireNote': false},
  {'key': 'completed',                      'label': 'مكتمل',                     'icon': Icons.task_alt_rounded,         'tone': 'success', 'requireNote': false},
  {'key': 'accepted',                       'label': 'مقبول نهائيًا',             'icon': Icons.star_rounded,             'tone': 'success', 'requireNote': false},
  {'key': 'rejected',                       'label': 'مرفوض',                     'icon': Icons.cancel_outlined,          'tone': 'danger',  'requireNote': false},
];

// Common document types for "additional documents required" picker
const List<String> kCommonDocTypes = [
  'جواز السفر',
  'كشف الدرجات / الشهادة الأكاديمية',
  'شهادة اللغة (IELTS / TOEFL)',
  'خطاب توصية',
  'السيرة الذاتية (CV)',
  'خطاب الدوافع',
  'عقد العمل / إثبات الدخل',
  'كشف حساب بنكي',
  'وثيقة التأمين الصحي',
  'صورة شخصية',
  'شهادة الميلاد',
  'شهادة الجنسية / الهوية',
  'أخرى',
];

Color _toneColor(String? tone) {
  switch (tone) {
    case 'success': return AppColors.success;
    case 'warning': return AppColors.warning;
    case 'danger':  return AppColors.danger;
    default:        return AppColors.info;
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
    final currentKey =
        _app['detailedStatus'] as String? ?? _app['status'] as String?;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSheet(
        currentKey: currentKey,
        onSelect: (key) async {
          Navigator.pop(context);
          final statusDef = kApplicationDetailedStatuses.firstWhere(
              (s) => s['key'] == key,
              orElse: () => {'requireNote': false});

          if (key == 'additional-documents-required') {
            // Special sheet: pick document type + write note
            await _showAdditionalDocSheet();
            return;
          }

          String? note;
          final requireNote = statusDef['requireNote'] == true;
          // Always show note dialog for statuses that require one, optional for others
          if (requireNote ||
              key == 'conditional-admission' ||
              key == 'rejected') {
            note = await _askForNote(key, required: requireNote);
            if (note == null) return; // cancelled
          }
          await _updateStatus(key, note: note?.isEmpty == true ? null : note);
        },
      ),
    );
  }

  Future<void> _showAdditionalDocSheet() async {
    String? selectedType;
    final noteCtrl = TextEditingController();
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
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
                  child: Text('مستند إضافي مطلوب',
                      style: AppTextStyles.screenTitle),
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('حدّد نوع المستند المطلوب من الطالب',
                      style: AppTextStyles.caption),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: (MediaQuery.of(ctx).size.height * 0.35 -
                            MediaQuery.of(ctx).viewInsets.bottom)
                        .clamp(80.0, double.infinity)),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: kCommonDocTypes.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 46),
                  itemBuilder: (_, i) {
                    final t = kCommonDocTypes[i];
                    final sel = selectedType == t;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                          sel
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: sel ? AppColors.navy : AppColors.textSecondary,
                          size: 20),
                      title: Text(t,
                          style: AppTextStyles.body.copyWith(
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                      onTap: () => setLocal(() => selectedType = t),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: noteCtrl,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'ملاحظة إضافية للطالب (اختياري)...',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy),
                        onPressed: selectedType == null
                            ? null
                            : () => Navigator.pop(ctx, {
                                  'type': selectedType!,
                                  'note': noteCtrl.text.trim(),
                                }),
                        child: const Text('إرسال',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    final note =
        '${result['type']}${result['note']!.isNotEmpty ? " — ${result['note']}" : ""}';
    await _updateStatus('additional-documents-required', note: note);
  }

  Future<String?> _askForNote(String statusKey,
      {bool required = false}) async {
    final label = kApplicationDetailedStatuses
        .firstWhere((s) => s['key'] == statusKey,
            orElse: () => {'label': 'تحديث'})['label'] as String;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ملاحظة — $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (required)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.warning),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'يجب كتابة المستندات الناقصة حتى يعرف الطالب ما يحتاج رفعه.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: ctrl,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              decoration: InputDecoration(
                  hintText: required
                      ? 'مثال: يرجى رفع جواز السفر وكشف الدرجات...'
                      : 'أدخل ملاحظة للطالب (اختياري)...'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () {
                if (required && ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, ctrl.text);
              },
              child: Text(required ? 'إرسال' : 'تأكيد')),
        ],
      ),
    );
  }

  Future<void> _viewDocument(String? docId, String? filePath, String docName) async {
    try {
      String url;
      // Legacy docs already have a direct public URL in filePath.
      // New private-storage docs need a signed URL from the access endpoint.
      if (filePath != null && filePath.startsWith('https://')) {
        url = filePath;
      } else if (docId != null) {
        url = await UniversityRepository.instance.getDocumentAccessUrl(docId);
      } else {
        throw Exception('no url');
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('تعذر فتح الملف: $docName'),
              backgroundColor: AppColors.danger));
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        final msg = e.statusCode == 409
            ? 'هذا المستند مخزّن بتنسيق قديم — تواصل مع فريق Study Birds للوصول إليه.'
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg), backgroundColor: AppColors.warning));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر تحميل رابط الملف'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _app['student'] as Map<String, dynamic>?;
    final program = _app['program'] as Map<String, dynamic>?;
    final documents = _app['documents'] as List<dynamic>? ?? [];
    final timeline = _app['statusTimeline'] as List<dynamic>? ?? [];
    final meta = appStatusMeta(_app);
    final name = student?['name'] as String? ?? '—';
    final email = student?['email'] as String? ?? '';
    final programName =
        program?['title'] as String? ?? program?['name'] as String? ?? '—';
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
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
                  _buildHeader(initials, name, email, programName, meta),
                  const SizedBox(height: 16),
                  const Text('المستندات المقدمة',
                      style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  _buildDocuments(documents),
                  const SizedBox(height: 16),
                  if (timeline.isNotEmpty) ...[
                    const Text('سجل التحديثات',
                        style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 10),
                    _buildTimeline(timeline),
                    const SizedBox(height: 16),
                  ],
                  const Text('الإجراءات', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _updating ? 'جاري التحديث...' : 'تحديث حالة الطلب',
                    onPressed: _updating ? null : _showStatusSheet,
                    icon: Icons.update_rounded,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
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
              const Icon(Icons.school_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(programName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Documents list with view button ─────────────────────────────────────────
  Widget _buildDocuments(List<dynamic> documents) {
    // Filter out unpopulated refs (strings instead of maps)
    final populated =
        documents.where((d) => d is Map<String, dynamic>).toList();

    if (populated.isEmpty) {
      return AppCard(
        child: Row(
          children: const [
            Icon(Icons.inbox_outlined, color: AppColors.textSecondary, size: 20),
            SizedBox(width: 10),
            Text('لم يرفع الطالب أي مستندات بعد.',
                style: AppTextStyles.caption),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: populated.asMap().entries.map((e) {
          final idx = e.key;
          final doc = e.value as Map<String, dynamic>;
          final docMeta = docStatusMeta(doc);
          final docId = doc['_id'] as String?;
          final docName = docTypeLabel(doc['type'] as String?);
          final fileName = doc['fileName'] as String? ?? docName;
          final filePath = doc['filePath'] as String?;
          final hasFile = docId != null;

          return Column(
            children: [
              if (idx != 0)
                const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insert_drive_file_outlined,
                          size: 17, color: AppColors.navy),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(docName, style: AppTextStyles.body),
                          if (fileName != docName)
                            Text(fileName,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(label: docMeta.label, color: docMeta.color),
                    if (hasFile) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _viewDocument(docId, filePath, docName),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 14, color: AppColors.navy),
                              SizedBox(width: 4),
                              Text('عرض',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Timeline ─────────────────────────────────────────────────────────────────
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
                      maxLines: 3,
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
              child:
                  Text('اختر الحالة الجديدة', style: AppTextStyles.screenTitle),
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
                final requireNote = s['requireNote'] == true;
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(s['icon'] as IconData, size: 18, color: color),
                  ),
                  title: Text(s['label'] as String,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isCurrent
                              ? AppColors.navy
                              : AppColors.textPrimary)),
                  subtitle: requireNote
                      ? const Text('تتطلب كتابة المستندات الناقصة',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.warning))
                      : null,
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
