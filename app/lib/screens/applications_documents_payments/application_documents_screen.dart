import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/feature_ui.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/config/app_theme.dart';
import 'documents_screens.dart';
import 'dart:async';
import '../../core/repositories/student_repository.dart';
import '../../core/utils/document_eligibility.dart';

class ApplicationDocumentsScreen extends StatefulWidget {
  final String applicationId;
  const ApplicationDocumentsScreen({super.key, required this.applicationId});
  @override
  State<ApplicationDocumentsScreen> createState() =>
      _ApplicationDocumentsScreenState();
}

class _ApplicationDocumentsScreenState
    extends State<ApplicationDocumentsScreen> {
  Map<String, dynamic>? application;
  List<Map<String, dynamic>> documents = [];
  final selection = <String, String>{};
  bool loading = true, busy = false;
  String? error;
  StreamSubscription<List<dynamic>>? _documentSub;
  String? get token => AuthSession.instance.token;
  bool invalid(Map doc) =>
      doc['supersededBy'] != null || doc['archivedAt'] != null || doc['isLatest'] == false ||
      doc['status'] == 'rejected' ||
      ['missing', 'rejected', 'needs-revision', 'needs-translation', 'expired']
          .contains(doc['detailedStatus']);
  @override
  void initState() {
    super.initState();
    load();
    _documentSub = StudentRepository.instance.documentChanges.listen((docs) {
      if (mounted) { setState(() {
        documents = docs.whereType<Map<String, dynamic>>().where(isUsableLibraryDocument).toList();
        selection.removeWhere((type, id) => !documents.any((doc) => doc['_id'] == id));
      }); }
    });
  }

  @override
  void dispose() {
    _documentSub?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        ApiClient.instance
            .get('/applications/${widget.applicationId}', token: token),
        StudentRepository.instance.getDocuments(),
      ]);
      if (!mounted) return;
      setState(() {
        application = Json.map(result[0]);
        documents = (Json.list(result[1])).cast<Map<String, dynamic>>();
        selection.clear();
      });
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/applications_documents_payments/application_documents_screen.dart:51');
      if (mounted) {
        setState(() {
          error = 'تعذر تحميل مستندات الطلب. أعد المحاولة.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> upload(String type) async {
    if (busy) return;
    setState(() {
      busy = true;
    });
    try {
      if (await pickAndUploadDocument(context, type) && mounted) {
        await StudentRepository.instance.getDocuments(forceRefresh: true);
      }
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/applications_documents_payments/application_documents_screen.dart:72');
      if (mounted) {
        setState(() {
          error = 'تعذر تحميل الملف.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> attach(String type) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('إرفاق المستند بالطلب؟'),
              content: const Text(
                  'سيُحفظ المستند السابق في سجل التغييرات ويُرسل البديل للمراجعة. حالة القبول لا تتغير تلقائيًا.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('رجوع')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('إرفاق'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ApiClient.instance.patch(
          '/applications/${widget.applicationId}/documents',
          token: token,
          body: {
            'documentId': selection[type],
            'version': application!['__v'] ?? 0
          });
      if (mounted) Navigator.pop(context, result);
    } catch (issue) {
      if (mounted) {
        setState(() {
          error = issue is ApiException && issue.statusCode == 409
              ? 'تغير الطلب أو لم يعد يقبل التعديل. حدّث البيانات وراجع حالة المستند.'
              : 'تعذر إرفاق المستند. تحقق من الاتصال وصلاحية الملف.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = !['accepted', 'rejected']
            .contains(application?['status']) &&
        [
          'draft',
          'documents-missing',
          'ready-to-apply',
          'submitted',
          'under-review',
          'additional-documents-required'
        ].contains(application?['detailedStatus'] ?? application?['status']);
    final requests = (Json.listOrNull(application?['documentRequests']) ?? [])
        .cast<Map<String, dynamic>>()
        .where((item) => ['requested', 'submitted'].contains(item['status']))
        .toList();
    final attached =
        (Json.listOrNull(application?['documents']) ?? []).cast<Map<String, dynamic>>();
    final program = Json.mapOrNull(application?['program']) ?? {};
    final types = <String>{
      ...(Json.listOrNull(application?['requiredDocumentTypes']) ??
              Json.listOrNull(program['requiredDocumentTypes']) ??
              ['passport', 'biometric-photo', 'latest-qualification'])
          .cast<String>(),
      ...requests.map((item) => item['type'] as String),
      ...attached.map((doc) => doc['type'] as String)
    };
    return AppScaffold(
        title: 'استكمال مستندات الطلب',
        body: RefreshIndicator(
          onRefresh: load,
          color: AppColors.navy,
          child: loading
              ? const LoadingState(message: 'جاري تحميل المستندات...')
              : application == null
                  ? ErrorState(message: error ?? 'تعذر التحميل', onRetry: load)
                  : ListView(padding: const EdgeInsets.all(16), physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), children: [
                    const Text(
                        'ارفع ملفًا جديدًا أو اختر ملفًا صالحًا من مستنداتك، ثم أرفقه بهذا الطلب.',
                        style: AppTextStyles.body),
                    const SizedBox(height: 16),
                    for (final type in types)
                      Builder(builder: (context) {
                        final current = attached
                            .where((doc) => doc['type'] == type)
                            .toList();
                        final needsUpdate = current.isEmpty ||
                            current.every(invalid) ||
                            requests.any((item) =>
                                item['type'] == type &&
                                item['status'] == 'requested');
                        final choices = documents
                            .where((doc) =>
                                doc['type'] == type &&
                                !invalid(doc) &&
                                !attached
                                    .any((old) => old['_id'] == doc['_id']))
                            .toList();
                        return AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(docTypeLabel(type),
                                  style: AppTextStyles.cardTitle),
                              for (final request in requests
                                  .where((item) => item['type'] == type))
                                Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                        '${request['status'] == 'requested' ? 'مطلوب من الفريق' : 'أُرسل للمراجعة'}: ${request['note']}',
                                        style: AppTextStyles.body)),
                              const SizedBox(height: 8),
                              Text(
                                  current.isEmpty
                                      ? 'مطلوب إرفاق مستند'
                                      : needsUpdate
                                          ? 'مطلوب تصحيح المستند'
                                          : 'المستند مرفق؛ تابع نتيجة المراجعة',
                                  style: AppTextStyles.caption),
                              if (needsUpdate && !editable)
                                const Text(
                                    'هذا الطلب لا يقبل تعديل المستندات حاليًا. تواصل مع فريقك.'),
                              if (needsUpdate && editable) ...[
                                if (choices.isNotEmpty)
                                  DropdownButton<String>(
                                      isExpanded: true,
                                      value: selection[type],
                                      hint: const Text('اختر المستند البديل'),
                                      items: choices
                                          .map((doc) => DropdownMenuItem(
                                              value: doc['_id'] as String,
                                              child: Text('${doc['fileName']}',
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: busy
                                          ? null
                                          : (value) => setState(() {
                                                if (value != null) {
                                                  selection[type] = value;
                                                }
                                              })),
                                TextButton.icon(
                                    onPressed: busy ? null : () => upload(type),
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('تصوير أو رفع مستند')),
                                if (selection[type] != null)
                                  FilledButton(
                                      onPressed:
                                          busy ? null : () => attach(type),
                                      child: const Text('إرفاق بالطلب')),
                              ],
                            ]));
                      }),
                    if (error != null)
                      InlineNotice(error!, error: true),
                    if (busy) const Center(child: CircularProgressIndicator()),
                    TextButton(
                        onPressed: busy ? null : load,
                        child: const Text('تحديث البيانات')),
                  ])));
  }
}
