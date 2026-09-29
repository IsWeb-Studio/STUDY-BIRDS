import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import 'generic_crud_screen.dart';

class AdminScholarshipsScreen extends StatelessWidget {
  const AdminScholarshipsScreen({super.key});
  String? get token => AuthSession.instance.token;
  @override
  Widget build(BuildContext context) => GenericCrudScreen(
        title: 'إدارة المنح',
        fields: const [
          CrudField('title', 'اسم المنحة', required: true),
          CrudField('university', 'الجامعة'),
          CrudField('country', 'الدولة'),
          CrudField('degree', 'الدرجة'),
          CrudField('funding', 'التمويل / نسبة المنحة'),
          CrudField('eligibility', 'شروط الأهلية',
              type: CrudFieldType.multiline),
          CrudField('deadline', 'آخر موعد (YYYY-MM-DD)'),
          CrudField('active', 'منشورة', type: CrudFieldType.boolean)
        ],
        fetchItems: () async => await ApiClient.instance
            .get('/scholarships/manage', token: token) as List,
        createItem: (body) async => await ApiClient.instance
                .post('/scholarships', token: token, body: body)
            as Map<String, dynamic>,
        updateItem: (id, body) async => await ApiClient.instance
                .put('/scholarships/$id', token: token, body: body)
            as Map<String, dynamic>,
        itemTitle: (row) => '${row['title']}',
        itemSubtitle: (row) => row['active'] == true ? 'منشورة' : 'مسودة',
      );
}

class ScholarshipApplicationsScreen extends StatefulWidget {
  const ScholarshipApplicationsScreen({super.key});
  @override
  State<ScholarshipApplicationsScreen> createState() =>
      _ScholarshipApplicationsScreenState();
}

class _ScholarshipApplicationsScreenState
    extends State<ScholarshipApplicationsScreen> {
  late Future<dynamic> future = fetch();
  String? saving;
  Future<dynamic> fetch() => ApiClient.instance
      .get('/scholarships/entries', token: AuthSession.instance.token);
  Future<void> update(Map row, String status) async {
    if (await showAppConfirmDialog(context,
            title: 'تحديث طلب المنحة',
            message: 'حفظ الحالة الجديدة لهذا الطلب؟',
            confirmLabel: 'حفظ') !=
        true) return;
    setState(() => saving = '${row['_id']}');
    try {
      await ApiClient.instance.patch('/scholarships/${row['_id']}/status',
          token: AuthSession.instance.token, body: {'status': status});
      if (mounted) setState(() => future = fetch());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'تعذر تحديث الطلب')));
    } finally {
      if (mounted) setState(() => saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'طلبات المنح',
      body: FutureBuilder(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return ErrorState(
                  message: 'تعذر تحميل الطلبات',
                  onRetry: () => setState(() => future = fetch()));
            if (!snapshot.hasData) return const LoadingState();
            final rows = snapshot.data as List;
            if (rows.isEmpty)
              return const EmptyState(
                  icon: Icons.school_outlined,
                  title: 'لا توجد طلبات',
                  message: 'ستظهر طلبات الطلاب هنا.');
            return RefreshIndicator(
              onRefresh: () async { setState(() => future = fetch()); await future; },
              color: AppColors.navy,
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: rows
                      .map((row) => AppCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${row['student']?['name'] ?? 'طالب'}',
                                    style: AppTextStyles.cardTitle),
                                Text('${row['scholarship']?['title'] ?? 'منحة'}'),
                                DropdownButton<String>(
                                    value: row['status'] as String,
                                    items: const {
                                      'submitted': 'تم التقديم',
                                      'reviewing': 'قيد المراجعة',
                                      'accepted': 'مقبول',
                                      'rejected': 'غير مقبول'
                                    }
                                        .entries
                                        .map((e) => DropdownMenuItem(
                                            value: e.key, child: Text(e.value)))
                                        .toList(),
                                    onChanged: saving != null
                                        ? null
                                        : (value) {
                                            if (value != null)
                                              update(row as Map, value);
                                          })
                              ])))
                      .toList()),
            );
          }));
}
