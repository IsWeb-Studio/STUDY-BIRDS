import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_session.dart';
import '../roles/generic_crud_screen.dart';

class StudentListingsScreen extends StatefulWidget {
  final String kind;
  const StudentListingsScreen({super.key, required this.kind});
  @override
  State<StudentListingsScreen> createState() => _StudentListingsScreenState();
}

class _StudentListingsScreenState extends State<StudentListingsScreen> {
  late Future<dynamic> _rows;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _rows = ApiClient.instance.get('/students/listings?kind=${widget.kind}', token: AuthSession.instance.token); }
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: widget.kind == 'offer' ? 'عروض وخصومات الطلاب' : 'فرص العمل والتدريب',
    body: FutureBuilder<dynamic>(future: _rows, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'تعذر تحميل القائمة', onRetry: () => setState(_reload));
      if (!snapshot.hasData) return const LoadingState();
      final rows = snapshot.data as List;
      return RefreshIndicator(onRefresh: () async { setState(_reload); await _rows; },
        child: ListView(physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), padding: const EdgeInsets.all(16), children: [
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد إعلانات سارية حاليًا')),
          for (final row in rows) AppCard(margin: const EdgeInsets.only(bottom: 12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['title']}', style: AppTextStyles.cardTitle),
              for (final key in ['organization', 'country', 'description'])
                if ('${row[key] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${row[key]}')),
              if ('${row['terms'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 8), const Text('الشروط', style: AppTextStyles.sectionLabel), Text('${row['terms']}'),
              ],
              if (row['expiresAt'] != null) Text('ينتهي في: ${'${row['expiresAt']}'.split('T').first}'),
              if ('${row['url'] ?? ''}'.isNotEmpty) TextButton(onPressed: () async {
                final uri = Uri.tryParse('${row['url']}');
                if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return;
                try {
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception();
                } catch (_) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: Text('تعذر فتح الرابط')));
                }
              }, child: Text(widget.kind == 'offer' ? 'الاستفادة من العرض' : 'تفاصيل التقديم')),
            ],
          )),
        ]));
    }),
  );
}

class AdminStudentListingsScreen extends StatelessWidget {
  final String kind;
  const AdminStudentListingsScreen({super.key, required this.kind});
  static const path = '/admin/community-posts/listings';
  @override
  Widget build(BuildContext context) => GenericCrudScreen(
    title: kind == 'offer' ? 'إدارة عروض الطلاب' : 'إدارة فرص العمل والتدريب',
    fields: const [
      CrudField('title', 'العنوان', required: true),
      CrudField('organization', 'الجهة المقدمة'), CrudField('country', 'الدولة'),
      CrudField('description', 'الوصف', type: CrudFieldType.multiline),
      CrudField('terms', 'الشروط وطريقة الاستفادة', type: CrudFieldType.multiline),
      CrudField('url', 'رابط الاستفادة أو التقديم (https)'),
      CrudField('validFrom', 'بداية النشر (YYYY-MM-DD، اختياري)'),
      CrudField('expiresAt', 'الانتهاء (YYYY-MM-DD، اختياري)'),
      CrudField('published', 'نشر الإعلان للطلاب', type: CrudFieldType.boolean),
    ],
    fetchItems: () async => (await ApiClient.instance.get('$path?kind=$kind', token: AuthSession.instance.token) as List).map((row) => {
      ...row as Map,
      for (final key in ['validFrom', 'expiresAt']) key: row[key] == null ? '' : '${row[key]}'.split('T').first,
    }).toList(),
    createItem: (body) async => Map<String, dynamic>.from(await ApiClient.instance.post(path,
      token: AuthSession.instance.token, body: {...body, 'kind': kind}) as Map),
    updateItem: (id, body) async => Map<String, dynamic>.from(await ApiClient.instance.put('$path/$id',
      token: AuthSession.instance.token, body: {...body, 'kind': kind}) as Map),
    itemTitle: (row) => '${row['title']}',
    itemSubtitle: (row) => '${row['organization'] ?? ''} • ${row['published'] == true ? 'منشور ضمن فترة الصلاحية' : 'مسودة'}',
  );
}
