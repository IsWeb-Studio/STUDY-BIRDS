import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'catalog_browser.dart';
import 'catalog_detail.dart';
import '../../core/student_repository.dart';

class ProgramsExplorerScreen extends StatelessWidget {
  const ProgramsExplorerScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'البرامج الدراسية',
        body: CatalogBrowser(
            onOpen: (p) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProgramDetailScreen(
                    programId: p['_id'] as String, initialData: p)))),
      );
}

class ProgramFinderScreen extends StatelessWidget {
  const ProgramFinderScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'مكتشف البرامج',
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
  String _studyStyle = 'متوازن';

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
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال بياناتك، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مكتشف التخصص',
      showBackButton: _step == 0,
      actions: _step > 0
          ? [TextButton(
              onPressed: () => setState(() => _step--),
              child: const Text('السابق', style: TextStyle(color: Colors.white)))]
          : null,
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
                Text('الخطوة ${_step + 1} من ${_steps.length}',
                    style: AppTextStyles.caption),
                Text(_steps[_step],
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
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 12.5)),
                  ),
                PrimaryButton(
                  label: _step < _steps.length - 1
                      ? 'التالي'
                      : _submitting ? 'جاري البحث...' : 'اعرض التخصصات المناسبة',
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
                const Text('النتائج استرشادية وليست قرارًا نهائيًا.',
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
      const Text('ما المجالات التي تشغل اهتمامك؟',
          style: AppTextStyles.cardTitle),
      const SizedBox(height: 4),
      const Text('اختر كل ما ينطبق عليك (اختيار واحد على الأقل)',
          style: AppTextStyles.caption),
      const SizedBox(height: 16),
      _chips(_interestOptions, _interests),
    ],
  );

  Widget _stepWorkEnv() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('كيف تتخيل يوم عملك المستقبلي؟',
          style: AppTextStyles.cardTitle),
      const SizedBox(height: 4),
      const Text('اختر البيئات التي تجذبك', style: AppTextStyles.caption),
      const SizedBox(height: 16),
      _chips(_workEnvOptions, _workEnvs),
    ],
  );

  Widget _stepPreferences() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('تفضيلاتك الدراسية', style: AppTextStyles.cardTitle),
      const SizedBox(height: 16),
      _dropdown('الدرجة العلمية', _degree,
          ['بكالوريوس', 'ماجستير', 'دكتوراه', 'دبلوم'],
          (v) => setState(() => _degree = v)),
      const SizedBox(height: 12),
      _dropdown('لغة الدراسة المفضلة', _language,
          ['الإنجليزية', 'العربية', 'التركية', 'أي لغة'],
          (v) => setState(() => _language = v)),
      const SizedBox(height: 12),
      _dropdown('نمط التعلم المفضل', _studyStyle,
          ['متوازن (نظري وعملي)', 'عملي بالدرجة الأولى', 'نظري وبحثي'],
          (v) => setState(() => _studyStyle = v)),
    ],
  );

  Widget _stepBudget() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('الميزانية والوجهة', style: AppTextStyles.cardTitle),
      const SizedBox(height: 4),
      const Text('هذه المعلومات تساعدنا في تضييق الخيارات',
          style: AppTextStyles.caption),
      const SizedBox(height: 16),
      _field('الميزانية السنوية التقريبية', 'مثال: 5,000\$ أو 20,000\$',
          _budgetCtrl, TextInputType.text),
      const SizedBox(height: 12),
      _field('الدولة المفضلة (اختياري)', 'مثال: تركيا، ماليزيا...',
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
              Text(o,
                  style: TextStyle(
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500)),
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
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
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
          Text(label, style: AppTextStyles.caption),
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
    final suggestedFields =
        (result['suggestedFields'] as List<dynamic>? ?? []).cast<String>();
    final suggestedCountries =
        (result['suggestedCountries'] as List<dynamic>? ?? []).cast<String>();
    final summary = result['recommendationSummary'] as String?;

    return AppScaffold(
      title: 'الاقتراحات المناسبة لك',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (summary != null) ...[
            AppCard(child: Text(summary, style: AppTextStyles.body)),
            const SizedBox(height: 12),
          ],
          if (suggestedFields.isNotEmpty) ...[
            const Text('مجالات مقترحة', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedFields
                    .map((f) => StatusBadge(label: f, color: AppColors.orange))
                    .toList()),
            const SizedBox(height: 16),
          ],
          if (suggestedCountries.isNotEmpty) ...[
            const Text('دول مقترحة', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedCountries
                    .map((c) => StatusBadge(label: c, color: AppColors.info))
                    .toList()),
          ],
          const SizedBox(height: 16),
          const Text(
            'دي نتيجة استرشادية بناءً على إجاباتك. تصفّح البرامج والجامعات المرتبطة بالمجالات دي من قسم الاستكشاف.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
