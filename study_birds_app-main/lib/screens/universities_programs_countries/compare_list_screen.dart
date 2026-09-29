import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/catalog_repository.dart';
import '../../core/auth_session.dart';
import 'comparison_grid.dart';

class CompareListScreen extends StatefulWidget {
  const CompareListScreen({super.key});
  @override
  State<CompareListScreen> createState() => _CompareListScreenState();
}

class _CompareListScreenState extends State<CompareListScreen> {
  List<Map<String, dynamic>> universities = [];
  final selected = <String>{};
  bool loading = true, comparing = false;
  String? error;
  String query = '';
  Future<void> pendingSave = Future.value();
  late final String storageKey =
      'compare_universities_${AuthSession.instance.currentUser?.id ?? 'guest'}';
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
      final rows = await CatalogRepository.instance.getUniversities();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      universities = rows.map((e) => Map<String, dynamic>.from(e)).toList();
      selected.clear();
      selected.addAll((prefs.getStringList(storageKey) ?? [])
          .where((id) => universities.any((u) => u['_id'] == id))
          .take(3));
    } catch (_) {
      error = 'تعذر تحميل الجامعات';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggle(String id, bool value) async {
    if (value && selected.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر ثلاث جامعات كحد أقصى')));
      return;
    }
    setState(() {
      if (value) {
        selected.add(id);
      } else {
        selected.remove(id);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = selected.toList();
      pendingSave = pendingSave.catchError((Object _) {}).then((_) async {
        await prefs.setStringList(storageKey, ids);
      });
      await pendingSave;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر حفظ الاختيار على الجهاز')));
    }
  }

  String cell(Map<String, dynamic> u, String field) {
    final value = u[field];
    if (value == null) return 'غير محدد';
    if (field == 'country' && value is Map)
      return '${value['name'] ?? 'غير محدد'}';
    if (field == 'tuitionRange' && value is Map)
      return '${value['min'] ?? '—'} – ${value['max'] ?? '—'}';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final chosen =
        universities.where((u) => selected.contains(u['_id'])).toList();
    final filtered = universities
        .where((u) => '${u['name']} ${cell(u, 'country')} ${cell(u, 'city')}'
            .toLowerCase()
            .contains(query.trim().toLowerCase()))
        .toList();
    return AppScaffold(
      title: 'مقارنة الجامعات',
      actions: [
        IconButton(
            onPressed: load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))
      ],
      bottomBar: loading || error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: PrimaryButton(
                    label: comparing
                        ? 'تعديل الاختيار'
                        : 'مقارنة (${chosen.length})',
                    icon:
                        comparing ? Icons.edit_outlined : Icons.compare_arrows,
                    onPressed: comparing
                        ? () => setState(() => comparing = false)
                        : chosen.length < 2
                            ? null
                            : () => setState(() => comparing = true),
                  ))),
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.navy,
        child: loading
            ? const LoadingState()
            : error != null
                ? ErrorState(message: error!, onRetry: load)
                : FeatureBody(children: [
                  FeatureIntro(
                      title:
                          comparing ? 'قارن قبل أن تختار' : 'أي جامعة تناسبك؟',
                      subtitle: comparing
                          ? 'اطّلع على الفروق بين الجامعات التي اخترتها.'
                          : 'اختر جامعتين أو ثلاثًا. نحتفظ باختياراتك على هذا الجهاز.',
                      icon: Icons.account_balance_outlined),
                  if (!comparing) ...[
                    TextField(
                        decoration: featureInput('البحث عن جامعة',
                            hint: 'اسم الجامعة أو الدولة', icon: Icons.search),
                        onChanged: (v) => setState(() => query = v)),
                    const SizedBox(height: 16),
                    if (chosen.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final u in chosen)
                              InputChip(
                                  label: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 200),
                                      child: Text('${u['name']}',
                                          overflow: TextOverflow.ellipsis)),
                                  onDeleted: () => toggle('${u['_id']}', false))
                          ])),
                    if (filtered.isEmpty)
                      const InlineNotice('لا توجد جامعات مطابقة للبحث.'),
                    for (final u in filtered)
                      Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: selected.contains(u['_id'])
                                      ? AppColors.navy
                                      : AppColors.border),
                              borderRadius: BorderRadius.circular(16)),
                          child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: CheckboxListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                activeColor: AppColors.navy,
                                title: Text('${u['name']}',
                                    style: AppTextStyles.cardTitle),
                                subtitle: Text(
                                    '${cell(u, 'country')} • ${cell(u, 'city')}',
                                    style: AppTextStyles.caption),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                value: selected.contains(u['_id']),
                                onChanged: (v) =>
                                    toggle('${u['_id']}', v ?? false),
                              ))),
                  ] else ...[
                    UniversityComparisonGrid(universities: chosen, value: cell),
                    const SizedBox(height: 20),
                    const InlineNotice(
                        'الرسوم كما وردت في بيانات الجامعة. راجع البرنامج لمعرفة رسومه النهائية.'),
                  ],
                ]),
        ),
    );
  }
}
