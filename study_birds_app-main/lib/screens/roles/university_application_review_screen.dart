import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/university_repository.dart';
import '../applications_documents_payments/applications_screens.dart' show appStatusMeta;
import '../applications_documents_payments/documents_screens.dart' show docStatusMeta, docTypeLabel;

const List<Map<String, String>> kApplicationDetailedStatuses = [
  {'key': 'documents-missing', 'label': 'مستندات ناقصة'},
  {'key': 'ready-to-apply', 'label': 'جاهز للتقديم'},
  {'key': 'under-review', 'label': 'قيد المراجعة'},
  {'key': 'additional-documents-required', 'label': 'مطلوب مستندات إضافية'},
  {'key': 'conditional-admission', 'label': 'قبول مشروط'},
  {'key': 'payment-required', 'label': 'الدفع مطلوب'},
  {'key': 'payment-verification', 'label': 'التحقق من الدفع'},
  {'key': 'final-admission', 'label': 'قبول نهائي'},
  {'key': 'visa-preparation', 'label': 'تجهيز التأشيرة'},
  {'key': 'completed', 'label': 'مكتمل'},
  {'key': 'accepted', 'label': 'مقبول نهائيًا'},
  {'key': 'rejected', 'label': 'مرفوض'},
];

class UniversityApplicationReviewScreen extends StatefulWidget {
  final String applicationId;
  final Map<String, dynamic> initialData;
  const UniversityApplicationReviewScreen({super.key, required this.applicationId, required this.initialData});

  @override
  State<UniversityApplicationReviewScreen> createState() => _UniversityApplicationReviewScreenState();
}

class _UniversityApplicationReviewScreenState extends State<UniversityApplicationReviewScreen> {
  late Map<String, dynamic> _app;
  bool _updating = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _app = widget.initialData;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final data = await UniversityRepository.instance.getApplicationById(widget.applicationId);
      if (mounted) setState(() => _app = data);
    } catch (_) {
      // keep whatever we already have
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _updateStatus(String detailedStatus) async {
    setState(() => _updating = true);
    try {
      final updated = await UniversityRepository.instance.updateApplicationStatus(widget.applicationId, detailedStatus: detailedStatus);
      if (!mounted) return;
      setState(() => _app = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الطلب'), backgroundColor: AppColors.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث الحالة'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _requestDocument() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب مستند إضافي'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'مثال: يرجى رفع كشف درجات مصدّق'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, reasonController.text), child: const Text('إرسال')),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await UniversityRepository.instance.requestDocument(widget.applicationId, reason: reason.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب للطالب'), backgroundColor: AppColors.success));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال الطلب'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _app['student'] as Map<String, dynamic>?;
    final program = _app['program'] as Map<String, dynamic>?;
    final documents = _app['documents'] as List<dynamic>? ?? [];
    final meta = appStatusMeta(_app);

    return AppScaffold(
      title: student?['name'] as String? ?? 'مراجعة طلب',
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.navy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(program?['title'] as String? ?? '—', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),
                _Row(label: 'الفصل الدراسي', value: program?['intake'] as String? ?? '—'),
                const Divider(height: 20),
                _Row(label: 'اللغة', value: program?['language'] as String? ?? '—'),
                const Divider(height: 20),
                _Row(label: 'البريد الإلكتروني', value: student?['email'] as String? ?? '—'),
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الحالة الحالية', style: AppTextStyles.caption), StatusBadge(label: meta.label, color: meta.color)]),
              ],
            ),
          ),
          const Text('المستندات المقدمة', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            const AppCard(child: Text('لم يرفع الطالب أي مستندات بعد.', style: AppTextStyles.caption))
          else
            AppCard(
              child: Column(
                children: documents.map((d) {
                  final doc = d as Map<String, dynamic>;
                  final docMeta = docStatusMeta(doc);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Expanded(child: Text(docTypeLabel(doc['type'] as String?), style: AppTextStyles.body)),
                        StatusBadge(label: docMeta.label, color: docMeta.color),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          const Text('تحديث حالة الطلب', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: kApplicationDetailedStatuses.map((s) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s['label']!, textAlign: TextAlign.right),
                  trailing: _updating ? null : const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary),
                  onTap: _updating ? null : () => _updateStatus(s['key']!),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _requestDocument,
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48), side: const BorderSide(color: AppColors.border)),
            child: const Text('طلب مستند إضافي من الطالب'),
          ),
        ],
        ),
      ),
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
        Flexible(child: Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
