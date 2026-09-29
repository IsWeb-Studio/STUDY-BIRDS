import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/admin_modules_repository.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;
import '../applications_documents_payments/documents_screens.dart'
    show docStatusMeta, docTypeLabel;

class AdminApplicationsScreen extends StatefulWidget {
  final String? applicationId;
  const AdminApplicationsScreen({super.key, this.applicationId});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  List<dynamic> _apps = [];
  bool _loading = true;
  String? _error;

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
      final data = await AdminModulesRepository.instance.getApplications();
      if (!mounted) return;
      setState(() {
        _apps = widget.applicationId == null
            ? data
            : data
                .where((item) => item['_id'] == widget.applicationId)
                .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الطلبات.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'طلبات الطلاب',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _apps.isEmpty
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        title: 'لا توجد طلبات',
                        message: 'ستظهر هنا كل طلبات الطلاب على المنصة.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _apps.length,
                      itemBuilder: (context, i) {
                        final app = _apps[i] as Map<String, dynamic>;
                        final student = app['student'] as Map<String, dynamic>?;
                        final program = app['program'] as Map<String, dynamic>?;
                        final university =
                            program?['university'] as Map<String, dynamic>?;
                        final meta = appStatusMeta(app);
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(student?['name'] as String? ?? '—',
                                        style: AppTextStyles.cardTitle),
                                    Text(
                                        '${university?['name'] ?? ''} — ${program?['title'] ?? ''}',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              StatusBadge(label: meta.label, color: meta.color),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}

class AdminStudentDocumentsScreen extends StatefulWidget {
  const AdminStudentDocumentsScreen({super.key});

  @override
  State<AdminStudentDocumentsScreen> createState() =>
      _AdminStudentDocumentsScreenState();
}

class _AdminStudentDocumentsScreenState
    extends State<AdminStudentDocumentsScreen> {
  List<dynamic> _docs = [];
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
      final data = await AdminModulesRepository.instance.getStudentDocuments();
      if (!mounted) return;
      setState(() { _docs = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'تعذر تحميل المستندات.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مستندات الطلاب',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _docs.isEmpty
                    ? const EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'لا توجد مستندات',
                        message: 'ستظهر هنا مستندات كل الطلاب.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _docs.length,
                      itemBuilder: (context, i) {
                        final doc = _docs[i] as Map<String, dynamic>;
                        final student = doc['student'] as Map<String, dynamic>?;
                        final meta = docStatusMeta(doc);
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${student?['name'] ?? '—'} — ${docTypeLabel(doc['type'] as String?)}',
                                        style: AppTextStyles.cardTitle),
                                    Text(student?['email'] as String? ?? '',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              StatusBadge(label: meta.label, color: meta.color),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
