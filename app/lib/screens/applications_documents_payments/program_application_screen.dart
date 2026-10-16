import '../../core/services/realtime_sync_service.dart';
import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/feature_ui.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_session.dart';
import '../../core/repositories/catalog_repository.dart';
import 'applications_screens.dart';
import 'documents_screens.dart';
import 'dart:async';
import '../../core/repositories/student_repository.dart';
import '../../core/utils/document_eligibility.dart';

class ProgramApplicationScreen extends StatefulWidget {
  final String programId;
  const ProgramApplicationScreen({super.key, required this.programId});

  @override
  State<ProgramApplicationScreen> createState() =>
      _ProgramApplicationScreenState();
}

class _ProgramApplicationScreenState extends State<ProgramApplicationScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'name',
      'email',
      'phone',
      'nationality',
      'currentEducation',
      'gpa',
      'intake',
      'address',
      'notes'
    ])
      key: TextEditingController(),
  };
  Map<String, dynamic>? program;
  List<Map<String, dynamic>> documents = [];
  final selected = <String, String>{};
  bool loading = true;
  bool busy = false;
  String? error;
  StreamSubscription<List<dynamic>>? _documentSub;
  String? get token => AuthSession.instance.token;
  List<String> get requiredTypes =>
      (Json.listOrNull(program?['requiredDocumentTypes']) ??
              ['passport', 'biometric-photo', 'latest-qualification'])
          .cast<String>();

  @override
  void initState() {
    super.initState();
    load();
    _documentSub = StudentRepository.instance.documentChanges.listen((data) {
      if (mounted && program != null) setState(() => updateDocuments(data));
    });
  }

  @override
  void dispose() {
    _documentSub?.cancel();
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        CatalogRepository.instance.getProgramById(widget.programId),
        ApiClient.instance.get('/students/profile', token: token),
        StudentRepository.instance.getDocuments(),
      ]);
      if (!mounted) return;
      program = Json.map(values[0]);
      final profile = Json.mapOrNull(values[1]) ?? {};
      final user = Json.mapOrNull(profile['user']) ?? {};
      for (final key in fields.keys) {
        if (fields[key]!.text.isEmpty) {
          fields[key]!.text = '${profile[key] ?? user[key] ?? ''}';
        }
      }
      updateDocuments(Json.list(values[2]));
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/applications_documents_payments/program_application_screen.dart:82');
      if (mounted) error = 'تعذر تحميل بيانات التقديم. حاول مرة أخرى.';
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void updateDocuments(List data) {
    documents = data
        .cast<Map<String, dynamic>>()
        .where(isUsableLibraryDocument)
        .toList();
    for (final type in requiredTypes) {
      final choices = documents.where((doc) => doc['type'] == type).toList();
      if (!choices.any((doc) => doc['_id'] == selected[type])) {
        selected.remove(type);
        if (choices.isNotEmpty) selected[type] = choices.first['_id'] as String;
      }
    }
  }

  Future<void> upload(String type) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (await pickAndUploadDocument(context, type)) {
        final data =
            await StudentRepository.instance.getDocuments(forceRefresh: true);
        if (mounted) {
          setState(() {
            updateDocuments(Json.list(data));
          });
        }
      }
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/applications_documents_payments/program_application_screen.dart:130');
      if (mounted) {
        setState(() {
          error = 'تعذر تحديث قائمة المستندات.';
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

  Future<void> submit() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    if (requiredTypes.any((type) => !selected.containsKey(type))) {
      setState(() {
        error = 'أكمل المستندات المطلوبة قبل إرسال الطلب.';
      });
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('إرسال طلب التقديم؟'),
              content: const Text(
                  'تأكد من صحة بياناتك والمستندات المختارة. سيُرسل الطلب إلى فريق القبول للمراجعة.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('مراجعة')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('إرسال الطلب'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result =
          await ApiClient.instance.post('/applications', token: token, body: {
        'programId': widget.programId,
        'documentIds': requiredTypes.map((type) => selected[type]!).toList(),
        'notes': fields['notes']!.text.trim(),
        'applicantProfile': {
          for (final key in fields.keys.where((key) => key != 'notes'))
            key: fields[key]!.text.trim()
        },
      });
      RealtimeSyncService.instance.forceSync();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ApplicationDetailScreen(
              application: Json.map(result))));
    } catch (issue) {
      if (mounted) {
        setState(() {
          error = issue is ApiException
              ? issue.message
              : 'تعذر إرسال الطلب. راجع طلباتك قبل إعادة المحاولة.';
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
    return AppScaffold(
      title: 'التقديم على البرنامج',
      body: loading
          ? const LoadingState(message: 'جاري تجهيز طلبك...')
          : program == null
              ? ErrorState(message: error ?? 'تعذر التحميل', onRetry: load)
              : Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text('${program!['title'] ?? ''}',
                        style: AppTextStyles.screenTitle),
                    const SizedBox(height: 12),
                    const Text(
                        'راجع بياناتك واختر مستنداتك لإرسال الطلب إلى فريق القبول.'),
                    const SizedBox(height: 16),
                    for (final entry in const {
                      'name': 'الاسم الكامل',
                      'email': 'البريد الإلكتروني',
                      'phone': 'رقم الهاتف',
                      'nationality': 'الجنسية',
                      'currentEducation': 'المؤهل الحالي',
                      'gpa': 'المعدل',
                      'intake': 'موعد بدء الدراسة',
                      'address': 'العنوان',
                      'notes': 'ملاحظات إضافية'
                    }.entries)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                            controller: fields[entry.key],
                            enabled: !busy,
                            keyboardType: entry.key == 'email'
                                ? TextInputType.emailAddress
                                : entry.key == 'phone'
                                    ? TextInputType.phone
                                    : TextInputType.text,
                            decoration: InputDecoration(labelText: entry.value),
                            validator: (value) {
                              if (['name', 'email', 'phone']
                                      .contains(entry.key) &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'هذا الحقل مطلوب';
                              }
                              if (entry.key == 'email' &&
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value?.trim() ?? '')) {
                                return 'أدخل بريدًا إلكترونيًا صحيحًا';
                              }
                              return null;
                            },
                          )),
                    const Text('المستندات المطلوبة',
                        style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 12),
                    for (final type in requiredTypes)
                      AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(docTypeLabel(type), style: AppTextStyles.body),
                            Text(documents.any((doc) => doc['type'] == type)
                                ? 'موجود في مستنداتك؛ راجع الاختيار قبل إرسال الطلب'
                                : 'مستند مطلوب غير متوفر', style: AppTextStyles.caption),
                            if (documents.any((doc) => doc['type'] == type))
                              DropdownButton<String>(
                                  isExpanded: true,
                                  value: selected[type],
                                  items: documents
                                      .where((doc) => doc['type'] == type)
                                      .map((doc) => DropdownMenuItem(
                                          value: doc['_id'] as String,
                                          child: Text('${doc['fileName']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: busy
                                      ? null
                                      : (value) => setState(() {
                                            if (value != null) {
                                              selected[type] = value;
                                            }
                                          })),
                            TextButton.icon(
                                onPressed: busy ? null : () => upload(type),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('تصوير أو رفع مستند')),
                            if (selected[type] != null)
                              TextButton.icon(
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('عرض المستند'),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => DocumentDetailScreen(document: documents.firstWhere(
                                        (doc) => doc['_id'] == selected[type])))),
                              ),
                          ])),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: InlineNotice(error!, error: true)),
                    if (busy)
                      const Center(child: CircularProgressIndicator())
                    else
                      PrimaryButton(
                          label: 'مراجعة وإرسال الطلب', onPressed: submit),
                  ])),
    );
  }
}
