import 'catalog_language.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/repositories/catalog_repository.dart';
import '../../core/services/auth_session.dart';
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
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/universities_programs_countries/compare_list_screen.dart:45');
      error = cl('تعذر تحميل الجامعات', 'Could not load universities');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggle(String id, bool value) async {
    if (value && selected.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(content: Text(cl('اختر ثلاث جامعات كحد أقصى', 'Select up to three universities'))));
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
      pendingSave = pendingSave.catchError(ErrorReporter.silent('screens/universities_programs_countries/compare_list_screen.dart:69')).then((_) async {
        await prefs.setStringList(storageKey, ids);
      });
      await pendingSave;
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/universities_programs_countries/compare_list_screen.dart:72');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            AppSnackBar(content: Text(cl('تعذر حفظ الاختيار على الجهاز', 'Could not save your selection on this device'))));
    }
  }

  String cell(Map<String, dynamic> u, String field) {
    final value = u[field];
    if (value == null) return cl('غير محدد', 'Not specified');
    if (field == 'country' && value is Map)
      return catalogCountryName(Map<String, dynamic>.from(value));
    if (field == 'tuitionRange' && value is Map)
      return '${value['min'] ?? '—'} – ${value['max'] ?? '—'}';
    return catalogValue(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return CatalogLanguageBuilder(builder: _buildPage);
  }

  Widget _buildPage(BuildContext context) {
    final chosen =
        universities.where((u) => selected.contains(u['_id'])).toList();
    final filtered = universities
        .where((u) => '${u['name']} ${cell(u, 'country')} ${cell(u, 'city')}'
            .toLowerCase()
            .contains(query.trim().toLowerCase()))
        .toList();
    return AppScaffold(
      textDirection: CatalogLanguage.instance.direction,
      title: cl('مقارنة الجامعات', 'Compare universities'),
      actions: [
        const CatalogLanguageToggle(),
        IconButton(
            onPressed: load, tooltip: cl('تحديث', 'Refresh'), icon: const Icon(Icons.refresh))
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
                        ? cl('تعديل الاختيار', 'Edit selection')
                        : cl('مقارنة (${chosen.length})', 'Compare (${chosen.length})'),
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
                ? ErrorState(message: catalogValue(error!), onRetry: load)
                : FeatureBody(children: [
                  FeatureIntro(
                      title:
                          comparing ? cl('قارن قبل أن تختار', 'Compare before you choose') : cl('أي جامعة تناسبك؟', 'Which university suits you?'),
                      subtitle: comparing
                          ? cl('اطّلع على الفروق بين الجامعات التي اخترتها.', 'See how your selected universities compare.')
                          : cl('اختر جامعتين أو ثلاثًا. نحتفظ باختياراتك على هذا الجهاز.', 'Select two or three universities. Your selection is saved on this device.'),
                      icon: Icons.account_balance_outlined),
                  if (!comparing) ...[
                    TextField(
                        decoration: featureInput(cl('البحث عن جامعة', 'Search universities'),
                            hint: cl('اسم الجامعة أو الدولة', 'University or country name'), icon: Icons.search),
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
                      InlineNotice(cl('لا توجد جامعات مطابقة للبحث.', 'No universities match your search.')),
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
                                title: Text(catalogName(u, 'name'),
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
                    InlineNotice(
                        cl('الرسوم كما وردت في بيانات الجامعة. راجع البرنامج لمعرفة رسومه النهائية.', 'Fees are as published by the university. Check the program for its final tuition fees.')),
                  ],
                ]),
        ),
    );
  }
}
