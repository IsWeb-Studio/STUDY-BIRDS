import 'dart:async';
import 'package:study_birds/core/api_client.dart';
import '../../core/passport_scan.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_access.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_theme.dart';
import '../../core/status_info.dart';
import '../../core/student_repository.dart';
import '../../core/analytics_service.dart';
import '../../core/notification_scheduler.dart';
import '../../core/realtime_sync_service.dart';

/// Maps the backend's document status (legacy 3-value `status`, or the
/// richer 8-value `detailedStatus` when present) to Arabic label + color.
class DocStatusMeta {
  final String label;
  final Color color;
  const DocStatusMeta(this.label, this.color);
}

DocStatusMeta docStatusMeta(Map<String, dynamic> doc) {
  final info = StatusInfo.of(doc);
  if (info != null) return DocStatusMeta(info.label, info.color);
  final detailed = doc['detailedStatus'] as String?;
  switch (detailed ?? doc['status'] as String? ?? 'pending') {
    case 'missing':
      return const DocStatusMeta('مفقود', AppColors.neutral);
    case 'uploaded':
    case 'pending':
      return const DocStatusMeta('قيد المراجعة', AppColors.info);
    case 'under-review':
      return const DocStatusMeta('قيد المراجعة', AppColors.info);
    case 'approved':
    case 'verified':
      return const DocStatusMeta('تمت الموافقة', AppColors.success);
    case 'rejected':
      return const DocStatusMeta('مرفوض', AppColors.danger);
    case 'needs-revision':
      return const DocStatusMeta('يحتاج تعديل', AppColors.warning);
    case 'needs-translation':
      return const DocStatusMeta('مطلوب ترجمة', AppColors.warning);
    case 'expired':
      return const DocStatusMeta('منتهي الصلاحية', AppColors.warning);
    default:
      return const DocStatusMeta('قيد المراجعة', AppColors.info);
  }
}

/// Document type options the backend recognizes for application eligibility
/// (see applicationController.js requiredDocumentTypes) plus a few common
/// extras. Free text on the backend, but a fixed list keeps the app tidy.
const List<Map<String, String>> kDocumentTypes = [
  {'key': 'passport', 'label': 'جواز السفر'},
  {'key': 'biometric-photo', 'label': 'صورة شخصية'},
  {'key': 'latest-qualification', 'label': 'آخر مؤهل دراسي'},
  {'key': 'transcript', 'label': 'كشف الدرجات'},
  {'key': 'language-certificate', 'label': 'شهادة اللغة'},
  {'key': 'english-test', 'label': 'شهادة اختبار الإنجليزية'},
  {'key': 'high-school-certificate', 'label': 'شهادة الثانوية'},
  {'key': 'university-degree', 'label': 'الشهادة الجامعية'},
  {'key': 'birth-certificate', 'label': 'شهادة الميلاد'},
  {'key': 'bank-statement', 'label': 'كشف حساب بنكي'},
  {'key': 'no-criminal-record', 'label': 'شهادة عدم السوابق'},
  {'key': 'recommendation-letter', 'label': 'خطاب توصية'},
  {'key': 'personal-statement', 'label': 'خطاب الدافع'},
  {'key': 'cv', 'label': 'السيرة الذاتية'},
  {'key': 'other', 'label': 'أخرى'},
];

// Labels for keys returned by older website uploads and for translations.
// Keys already in kDocumentTypes are intentionally omitted here.
const Map<String, String> _extraDocumentLabels = {
  'translation': 'ترجمة معتمدة',
  'language-certificates': 'شهادات اللغة',
  'personal-photos': 'صور شخصية',
  'resume': 'السيرة الذاتية',
  'other-documents': 'مستندات أخرى',
  'police-clearance': 'صحيفة الحالة الجنائية',
  'financial-statement': 'إفادة مالية',
};

String docTypeLabel(String? key) {
  if (_extraDocumentLabels[key] case final label?) return label;
  return kDocumentTypes.firstWhere((t) => t['key'] == key,
      orElse: () => {'label': key ?? 'مستند'})['label']!;
}

/// Picks a file and uploads it as the given document type. Shared by
/// MyDocumentsScreen and DocumentDetailScreen (a pushed route is NOT a
/// widget-tree ancestor of the screen that opened it, so this can't be a
/// method looked up via findAncestorStateOfType — it's a standalone helper).
Future<bool> pickAndUploadDocument(BuildContext context, String type,
    {String? replaces, String? translationOf}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return false;

  final file = result.files.single;
  if (file.bytes == null) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة الملف المختار')));
    return false;
  }
  if (file.size > 10 * 1024 * 1024) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حجم الملف كبير جدًا (الحد الأقصى 10 ميجابايت)')));
    return false;
  }

  if (!context.mounted) return false;

  final sizeKb = file.size ~/ 1024;
  final sizeStr =
      sizeKb >= 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '$sizeKb KB';
  final progressNotifier = ValueNotifier<double>(0.0);
  final stageNotifier = ValueNotifier<String>(type == 'passport' && translationOf == null
      ? 'جارٍ مسح الجواز والتحقق منه على جهازك...'
      : 'جارٍ رفع المستند...');
  final cancellation = UploadCancellation();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: AlertDialog(
      actions: [TextButton(onPressed: cancellation.cancel, child: const Text('إلغاء الرفع'))],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<String>(valueListenable: stageNotifier,
            builder: (_, stage, __) => Text(stage, style: AppTextStyles.cardTitle)),
          const SizedBox(height: 10),
          Text(file.name,
              style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
          Text(sizeStr, style: AppTextStyles.caption),
          const SizedBox(height: 14),
          ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (_, value, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: value > 0 ? value : null,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.navy),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text(
                  value >= 1 ? 'جارٍ حفظ المستند...' : value > 0 ? '${(value * 100).round()}%' : 'يرجى الانتظار...',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    )),
  );

  try {
    await StudentRepository.instance.uploadDocument(
        fileBytes: file.bytes!,
        fileName: file.name,
        type: type,
        replaces: replaces,
        translationOf: translationOf,
        cancellation: cancellation,
        onPassportValidated: () => stageNotifier.value = 'تم فحص الجواز، جارٍ الرفع...',
        onProgress: (p) => progressNotifier.value = p);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم رفع المستند بنجاح'),
          backgroundColor: AppColors.success));
    }
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();
    if (error is ApiException && error.statusCode == 499) return false;
    if (error is PassportScanException) {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('اختر صورة واضحة لجواز السفر'),
        content: Text(error.message),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('حسنًا'))],
      ));
      return false;
    }
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعذّر رفع المستند',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
            'قد يكون السبب ضعف الاتصال أو مشكلة مؤقتة في الخادم.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('إعادة المحاولة',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (retry == true && context.mounted) {
      return pickAndUploadDocument(context, type,
          replaces: replaces, translationOf: translationOf);
    }
    return false;
  } finally {
    // The dialog may still be animating out, so dispose after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      progressNotifier.dispose();
      stageNotifier.dispose();
    });
  }
}

class _DocThumb extends StatelessWidget {
  final Map<String, dynamic> document;
  const _DocThumb({required this.document});
  @override
  Widget build(BuildContext context) {
    final name = (document['fileName'] as String? ?? '').toLowerCase();
    final isPdf = name.endsWith('.pdf');
    final isImg = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
    final thumbUrl = document['thumbnailUrl'] as String?;
    final color = isPdf ? AppColors.danger : isImg ? AppColors.orange : AppColors.navy;
    final icon = isPdf
        ? Icons.picture_as_pdf_outlined
        : isImg
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;
    if (isImg && thumbUrl != null && thumbUrl.isNotEmpty) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(thumbUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 19))));
    }
    return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 19));
  }
}

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  List<dynamic> _docs = [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  StreamSubscription<DateTime>? _syncSub;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('my_documents');
    _load();
    _syncSub = RealtimeSyncService.instance.onTick.listen((_) {
      if (_uploading) return;
      StudentRepository.instance
          .getDocuments(forceRefresh: true)
          .then((docs) { if (mounted) setState(() => _docs = docs.whereType<Map>().where((d) => d['isLatest'] != false && d['translationOf'] == null).toList()); })
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
      final docs = await StudentRepository.instance.getDocuments();
      if (!mounted) return;
      // Schedule local expiry reminders for documents nearing their deadline.
      for (final d in docs) {
        final exp = DateTime.tryParse('${(d as Map<String, dynamic>)['expiresAt'] ?? ''}');
        final id = d['_id']?.toString();
        final name = d['originalName']?.toString() ?? d['type']?.toString() ?? 'مستند';
        if (exp != null && id != null && exp.isAfter(DateTime.now())) {
          NotificationScheduler.instance.scheduleDocumentExpiry(
              docId: id, docName: name, expiryDate: exp);
        }
      }
      setState(() {
        // Current files only: older versions and translations live inside
        // their document's detail screen (PRD 29).
        _docs = docs
            .whereType<Map>()
            .where((d) => d['isLatest'] != false && d['translationOf'] == null)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل مستنداتك.';
        _loading = false;
      });
    }
  }

  Future<void> _pickTypeAndUpload() async {
    final selectedType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      // Scrollable: the type list no longer fits a small phone's sheet.
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
                padding: EdgeInsets.all(16),
                child:
                    Text('اختر نوع المستند', style: AppTextStyles.cardTitle)),
            ...kDocumentTypes.map(
              (t) => ListTile(
                title: Text(t['label']!, textAlign: TextAlign.right),
                onTap: () => Navigator.of(context).pop(t['key']),
              ),
            ),
          ],
        ),
      ),
    );
    if (selectedType == null || !mounted) return;

    setState(() => _uploading = true);
    final success = await pickAndUploadDocument(context, selectedType);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (success) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مستنداتي',
      actions: [
        IconButton(
          onPressed: _uploading ? null : _pickTypeAndUpload,
          icon: _uploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل مستنداتك...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _docs.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'لا توجد مستندات بعد',
                        message:
                            'ابدأ برفع أول مستند من زر الإضافة أعلى الشاشة.',
                        ctaLabel: 'رفع مستند',
                        onCta: _pickTypeAndUpload,
                      )
                    : _buildDocsList(),
      ),
    );
  }

  Widget _buildDocsList() {
    final now = DateTime.now();
    final expiringSoon = _docs.whereType<Map<String, dynamic>>().where((d) {
      final exp = DateTime.tryParse('${d['expiresAt'] ?? ''}');
      return exp != null && exp.isAfter(now) && exp.difference(now).inDays <= 30;
    }).toList();
    final hasBanner = expiringSoon.isNotEmpty;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _docs.length + (hasBanner ? 1 : 0),
      itemBuilder: (context, i) {
        if (hasBanner && i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لديك ${expiringSoon.length} مستند${expiringSoon.length > 1 ? 'ات' : ''} ستنتهي صلاحيتها خلال 30 يومًا.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          );
        }
        final docIndex = hasBanner ? i - 1 : i;
        final d = _docs[docIndex] as Map<String, dynamic>;
        final meta = docStatusMeta(d);
        final info = StatusInfo.of(d);
        final needsAction = info != null &&
            (info.tone == 'action' || info.tone == 'danger');
        return AppCard(
          onTap: () async {
            final changed = await Navigator.of(context)
                .push<bool>(MaterialPageRoute(
                    builder: (_) => DocumentDetailScreen(document: d)));
            if (changed == true) _load();
          },
          child: Row(
            children: [
              _DocThumb(document: d),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(docTypeLabel(d['type'] as String?),
                      style: AppTextStyles.cardTitle),
                  if (needsAction)
                    Text(info.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: meta.color)),
                ],
              )),
              const SizedBox(width: 8),
              StatusBadge(label: meta.label, color: meta.color),
            ],
          ),
        );
      },
    );
  }
}

class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Uri? _previewUri;
  bool _loadingPreview = false;

  bool get _isImage {
    final name = (widget.document['fileName'] as String? ?? '').toLowerCase();
    return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
  }

  @override
  void initState() {
    super.initState();
    if (_isImage && widget.document['filePath'] is String) _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _loadingPreview = true);
    try {
      final uri = await resolveDocumentDownload(widget.document['filePath'] as String);
      if (mounted) setState(() => _previewUri = uri);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final meta = docStatusMeta(document);
    final info = StatusInfo.of(document);
    final reviewNote = document['reviewNote'] as String?;
    final createdAt = document['createdAt'] as String?;
    final expiresAt = DateTime.tryParse('${document['expiresAt']}')?.toLocal();
    // PRD 29: reviewer, translation state and version history from the server.
    final reviewer = document['reviewedBy'] is Map
        ? '${(document['reviewedBy'] as Map)['name'] ?? ''}'
        : '';
    final translation =
        document['translation'] is Map ? document['translation'] as Map : null;
    final translationStatus = translation?['status'] as String?;
    const translationLabels = {
      'required': 'مطلوبة',
      'uploaded': 'مرفوعة وقيد المراجعة',
      'approved': 'معتمدة',
      'needs-attention': 'تحتاج تصحيحًا',
      'not-required': 'غير مطلوبة',
    };
    final versions = (document['versions'] is List)
        ? (document['versions'] as List)
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .toList()
        : const <Map<String, dynamic>>[];

    return AppScaffold(
      title: docTypeLabel(document['type'] as String?),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: _loadingPreview
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.navy))
                  : _previewUri != null
                      ? Image.network(
                          _previewUri.toString(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.description_outlined,
                                  size: 48, color: AppColors.textSecondary)),
                        )
                      : Center(
                          child: Icon(
                            _isImage
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          )),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('اسم الملف', style: AppTextStyles.caption),
                      Flexible(
                          child: Text(document['fileName'] as String? ?? '—',
                              style: AppTextStyles.body,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تاريخ الرفع', style: AppTextStyles.caption),
                      Text(createdAt != null ? createdAt.split('T').first : '—',
                          style: AppTextStyles.body),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الحالة', style: AppTextStyles.caption),
                      StatusBadge(label: meta.label, color: meta.color),
                    ],
                  ),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صالح حتى', style: AppTextStyles.caption),
                        Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(expiresAt),
                            style: AppTextStyles.body),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المراجِع', style: AppTextStyles.caption),
                      Text(reviewer.isEmpty ? 'لم يُراجع بعد' : reviewer,
                          style: AppTextStyles.body),
                    ],
                  ),
                  if (translationStatus != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الترجمة', style: AppTextStyles.caption),
                        Text(
                            translationLabels[translationStatus] ??
                                translationStatus,
                            style: AppTextStyles.body.copyWith(
                                color: translationStatus == 'required' ||
                                        translationStatus == 'needs-attention'
                                    ? AppColors.warning
                                    : null)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // The server's explanation already includes the reviewer's reason.
            if (info != null) ...[
              const SizedBox(height: 12),
              StatusExplanationCard(info: info),
            ] else if (reviewNote != null && reviewNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(reviewNote,
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (document['filePath'] is String)
              OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('فتح المستند'),
                  onPressed: () async {
                    try {
                      final uri = await resolveDocumentDownload(
                          document['filePath'] as String);
                      if (!await launchUrl(uri,
                          mode: LaunchMode.externalApplication))
                        throw Exception('Cannot open file');
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'تعذر فتح الملف. تحقق من الجلسة والصلاحيات ثم حاول مجددًا.')));
                    }
                  }),
            // Linked to this file, so the current one moves to the history.
            PrimaryButton(
              label: 'رفع نسخة جديدة',
              icon: Icons.upload_file_rounded,
              onPressed: () async {
                final success = await pickAndUploadDocument(
                    context, document['type'] as String? ?? 'other',
                    replaces: '${document['_id']}');
                if (success && context.mounted) Navigator.of(context).pop(true);
              },
            ),
            if (translationStatus != null &&
                translationStatus != 'approved' &&
                translationStatus != 'uploaded') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.translate_rounded),
                label: const Text('رفع ترجمة معتمدة'),
                onPressed: () async {
                  final success = await pickAndUploadDocument(
                      context, 'translation',
                      translationOf: '${document['_id']}');
                  if (success && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ],
            if (versions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('سجل النسخ (${versions.length})',
                  style: AppTextStyles.sectionLabel),
              const SizedBox(height: 6),
              for (final version in versions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.history_rounded,
                      color: AppColors.textSecondary),
                  title: Text('${version['fileName'] ?? ''}',
                      style: AppTextStyles.body),
                  subtitle: Text(
                      [
                        if (DateTime.tryParse('${version['createdAt']}')
                            case final date?)
                          MaterialLocalizations.of(context)
                              .formatMediumDate(date.toLocal()),
                        StatusInfo.of(version)?.label ?? '',
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: AppTextStyles.caption),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
