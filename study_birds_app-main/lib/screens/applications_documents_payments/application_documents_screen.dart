import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import 'documents_screens.dart';

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
  String? get token => AuthSession.instance.token;
  bool invalid(Map doc) =>
      doc['status'] == 'rejected' ||
      ['missing', 'rejected', 'needs-revision', 'needs-translation', 'expired']
          .contains(doc['detailedStatus']);
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
      final result = await Future.wait([
        ApiClient.instance
            .get('/applications/${widget.applicationId}', token: token),
        ApiClient.instance.get('/students/documents', token: token),
      ]);
      if (!mounted) return;
      setState(() {
        application = result[0] as Map<String, dynamic>;
        documents = (result[1] as List).cast<Map<String, dynamic>>();
        selection.clear();
      });
    } catch (_) {
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
    setState(() {
      busy = true;
    });
    try {
      if (await pickAndUploadDocument(context, type) && mounted) await load();
    } catch (_) {
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
    final requests = (application?['documentRequests'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((item) => ['requested', 'submitted'].contains(item['status']))
        .toList();
    final attached =
        (application?['documents'] as List? ?? []).cast<Map<String, dynamic>>();
    final program = application?['program'] as Map<String, dynamic>? ?? {};
    final types = <String>{
      ...(application?['requiredDocumentTypes'] as List? ??
              program['requiredDocumentTypes'] as List? ??
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
                  : ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
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
                                    label: const Text('رفع مستند جديد')),
                                if (selection[type] != null)
                                  FilledButton(
                                      onPressed:
                                          busy ? null : () => attach(type),
                                      child: const Text('إرفاق بالطلب')),
                              ],
                            ]));
                      }),
                    if (error != null)
                      Text(error!,
                          style: const TextStyle(color: AppColors.danger)),
                    if (busy) const Center(child: CircularProgressIndicator()),
                    TextButton(
                        onPressed: busy ? null : load,
                        child: const Text('تحديث البيانات')),
                  ])));
  }
}
