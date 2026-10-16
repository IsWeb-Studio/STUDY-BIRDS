import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/feature_ui.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import 'catalog_browser.dart';
import 'catalog_detail.dart';
import 'catalog_language.dart';
import '../../core/repositories/student_repository.dart';

class ProgramsExplorerScreen extends StatelessWidget {
  const ProgramsExplorerScreen({super.key});
  @override
  Widget build(BuildContext context) => CatalogScaffold(
        title: () => cl('البرامج الدراسية', 'Study programs'),
        body: CatalogBrowser(
            onOpen: (p) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProgramDetailScreen(
                    programId: p['_id'] as String, initialData: p)))),
      );
}

class ProgramFinderScreen extends StatelessWidget {
  const ProgramFinderScreen({super.key});
  @override
  Widget build(BuildContext context) => CatalogScaffold(
        title: () => cl('مكتشف البرامج', 'Program finder'),
        body: CatalogBrowser(
            finder: true,
            onOrientation: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ProgramOrientationScreen())),
            onOpen: (p) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProgramDetailScreen(
                    programId: p['_id'] as String, initialData: p)))),
      );
}

class ProgramDetailScreen extends StatelessWidget {
  final String programId;
  final Map<String, dynamic>? initialData;
  const ProgramDetailScreen(
      {super.key, required this.programId, this.initialData});
  @override
  Widget build(BuildContext context) =>
      CatalogDetailPage(id: programId, initialData: initialData);
}

/// Orientation preferences saved through the student API.
class ProgramOrientationScreen extends StatefulWidget {
  const ProgramOrientationScreen({super.key});

  @override
  State<ProgramOrientationScreen> createState() =>
      _ProgramOrientationScreenState();
}

class _ProgramOrientationScreenState extends State<ProgramOrientationScreen> {
  int _step = 0;
  bool _submitting = false;
  String? _error;

  // Step 1 — interests
  final Set<String> _interests = {};
  static const _interestOptions = [
    'الطب والصحة', 'الهندسة والتكنولوجيا', 'الأعمال والاقتصاد',
    'الحاسوب والذكاء الاصطناعي', 'الفنون والتصميم', 'القانون والعلوم السياسية',
    'العلوم الأساسية', 'التعليم والتربية', 'الإعلام والصحافة', 'الصيدلة وطب الأسنان',
  ];

  // Step 2 — work environment
  final Set<String> _workEnvs = {};
  static const _workEnvOptions = [
    'مستشفى أو عيادة', 'مكتب وشركات', 'بحث علمي ومختبرات',
    'تعليم وجامعات', 'أعمال حرة ومشاريع', 'ميدان وعمل خارجي',
    'إبداع وفنون', 'حكومة وقطاع عام',
  ];

  // Step 3 — preferences
  String _degree = 'بكالوريوس';
  String _language = 'الإنجليزية';
  String _studyStyle = 'متوازن (نظري وعملي)';

  // Step 4 — budget & country
  final _budgetCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  static const _steps = ['اهتماماتك', 'بيئة العمل', 'تفضيلاتك', 'الميزانية'];

  bool get _canNext {
    return switch (_step) {
      0 => _interests.isNotEmpty,
      1 => _workEnvs.isNotEmpty,
      2 => true,
      3 => true,
      _ => false,
    };
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final result = await StudentRepository.instance.submitOrientationTest(
        favoriteSubjects: _interests.toList(),
        interestedFields: _interests.toList(),
        studyStyle: _studyStyle,
        preferredLanguage: _language,
        preferredCountry: _countryCtrl.text.trim(),
        approximateBudget: _budgetCtrl.text.trim(),
        desiredDegreeLevel: _degree,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ProgramFinderResultsScreen(result: result)));
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/universities_programs_countries/programs_screens.dart:119');
      if (mounted) setState(() => _error = 'تعذر إرسال بياناتك، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogLanguageBuilder(builder: _buildPage);
  }

  Widget _buildPage(BuildContext context) {
    return AppScaffold(
      textDirection: CatalogLanguage.instance.direction,
      title: cl('مكتشف التخصص', 'Find your field of study'),
      showBackButton: _step == 0,
      actions: [const CatalogLanguageToggle(), if (_step > 0) TextButton(
              onPressed: () => setState(() => _step--),
              child: Text(cl('السابق', 'Previous'), style: TextStyle(color: Colors.white)))],
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: List.generate(_steps.length, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(left: i < _steps.length - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step ? AppColors.orange : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(cl('الخطوة ${_step + 1} من ${_steps.length}', 'Step ${_step + 1} of ${_steps.length}'),
                    style: AppTextStyles.caption),
                Text(catalogValue(_steps[_step]),
                    style: AppTextStyles.caption.copyWith(color: AppColors.orange)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStep(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InlineNotice(catalogValue(_error!), error: true),
                  ),
                PrimaryButton(
                  label: _step < _steps.length - 1
                      ? cl('التالي', 'Next')
                      : _submitting ? cl('جاري البحث...', 'Searching...') : cl('اعرض التخصصات المناسبة', 'Show matching fields'),
                  onPressed: (!_canNext || _submitting)
                      ? null
                      : () {
                          if (_step < _steps.length - 1) {
                            setState(() => _step++);
                          } else {
                            _submit();
                          }
                        },
                ),
                const SizedBox(height: 6),
                Text(cl('النتائج استرشادية وليست قرارًا نهائيًا.', 'Results are guidance, not a final decision.'),
                    style: AppTextStyles.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _stepInterests(),
      1 => _stepWorkEnv(),
      2 => _stepPreferences(),
      3 => _stepBudget(),
      _ => const SizedBox(),
    };
  }

  Widget _stepInterests() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cl('ما المجالات التي تشغل اهتمامك؟', 'Which fields interest you?'),
          style: AppTextStyles.cardTitle),
      const SizedBox(height: 4),
      Text(cl('اختر كل ما ينطبق عليك (اختيار واحد على الأقل)', 'Select all that apply (at least one)'),
          style: AppTextStyles.caption),
      const SizedBox(height: 16),
      _chips(_interestOptions, _interests),
    ],
  );

  Widget _stepWorkEnv() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cl('كيف تتخيل يوم عملك المستقبلي؟', 'How do you imagine your future workday?'),
          style: AppTextStyles.cardTitle),
      const SizedBox(height: 4),
      Text(cl('اختر البيئات التي تجذبك', 'Select the work environments that appeal to you'), style: AppTextStyles.caption),
      const SizedBox(height: 16),
      _chips(_workEnvOptions, _workEnvs),
    ],
  );

  Widget _stepPreferences() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cl('تفضيلاتك الدراسية', 'Your study preferences'), style: AppTextStyles.cardTitle),
      const SizedBox(height: 16),
      _dropdown(cl('الدرجة العلمية', 'Degree level'), _degree,
          ['بكالوريوس', 'ماجستير', 'دكتوراه', 'دبلوم'],
          (v) => setState(() => _degree = v)),
      const SizedBox(height: 12),
      _dropdown(cl('لغة الدراسة المفضلة', 'Preferred study language'), _language,
          ['الإنجليزية', 'العربية', 'التركية', 'أي لغة'],
          (v) => setState(() => _language = v)),
      const SizedBox(height: 12),
      _dropdown(cl('نمط التعلم المفضل', 'Preferred learning style'), _studyStyle,
          ['متوازن (نظري وعملي)', 'عملي بالدرجة الأولى', 'نظري وبحثي'],
          (v) => setState(() => _studyStyle = v)),
    ],
  );

  Widget _stepBudget() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cl('الميزانية والوجهة', 'Budget and destination'), style: AppTextStyles.cardTitle),
      const SizedBox(height: 4),
      Text(cl('هذه المعلومات تساعدنا في تضييق الخيارات', 'These details help us narrow down your options'),
          style: AppTextStyles.caption),
      const SizedBox(height: 16),
      _field(cl('الميزانية السنوية التقريبية', 'Approximate annual budget'), cl('مثال: 5,000 USD أو 20,000 USD', 'For example: 5,000 USD or 20,000 USD'),
          _budgetCtrl, TextInputType.text),
      const SizedBox(height: 12),
      _field(cl('الدولة المفضلة (اختياري)', 'Preferred country (optional)'), cl('مثال: تركيا، ماليزيا...', 'For example: Turkey, Malaysia...'),
          _countryCtrl, TextInputType.text),
    ],
  );

  Widget _chips(List<String> options, Set<String> selected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((o) {
      final isSelected = selected.contains(o);
      return GestureDetector(
        onTap: () => setState(() =>
            isSelected ? selected.remove(o) : selected.add(o)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.orange.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
                color: isSelected ? AppColors.orange : AppColors.border,
                width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_rounded,
                    size: 13, color: AppColors.orange),
                const SizedBox(width: 4),
              ],
              Flexible(child: Text(catalogValue(o),
                  style: TextStyle(
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500))),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(catalogValue(label), style: AppTextStyles.caption),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: value,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(catalogValue(o))))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      );

  Widget _field(String label, String hint, TextEditingController ctrl,
      TextInputType type) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(catalogValue(label), style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: ctrl,
              keyboardType: type,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 12)),
            ),
          ),
        ],
      );
}

class ProgramFinderResultsScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const ProgramFinderResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return CatalogLanguageBuilder(builder: _buildPage);
  }

  Widget _buildPage(BuildContext context) {
    final suggestedFields =
        (Json.listOrNull(result['suggestedFields']) ?? []).cast<String>();
    final suggestedCountries =
        (Json.listOrNull(result['suggestedCountries']) ?? []).cast<String>();
    final summary = result['recommendationSummary'] as String?;

    return AppScaffold(
      textDirection: CatalogLanguage.instance.direction,
      actions: const [CatalogLanguageToggle()],
      title: cl('الاقتراحات المناسبة لك', 'Your recommendations'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (summary != null) ...[
            AppCard(child: Text(catalogValue(summary), style: AppTextStyles.body)),
            const SizedBox(height: 12),
          ],
          if (suggestedFields.isNotEmpty) ...[
            Text(cl('مجالات مقترحة', 'Suggested fields'), style: AppTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedFields
                    .map((f) => StatusBadge(label: catalogValue(f), color: AppColors.orange))
                    .toList()),
            const SizedBox(height: 16),
          ],
          if (suggestedCountries.isNotEmpty) ...[
            Text(cl('دول مقترحة', 'Suggested countries'), style: AppTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedCountries
                    .map((c) => StatusBadge(label: catalogValue(c), color: AppColors.info))
                    .toList()),
          ],
          const SizedBox(height: 16),
          Text(
            cl('دي نتيجة استرشادية بناءً على إجاباتك. تصفّح البرامج والجامعات المرتبطة بالمجالات دي من قسم الاستكشاف.', 'These recommendations are based on your answers. Explore related programs and universities in the Explore section.'),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
