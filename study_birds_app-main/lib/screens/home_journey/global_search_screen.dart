import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/analytics_service.dart';
import '../../core/catalog_repository.dart';
import '../universities_programs_countries/universities_screens.dart';
import '../universities_programs_countries/programs_screens.dart';
import '../universities_programs_countries/countries_scholarships_screens.dart';
import '../services_support/faq_screen.dart';
import '../services_support/knowledge_base_screen.dart';

/// Real search across the public catalog (universities, programs,
/// countries, FAQs). The backend has no dedicated search endpoint, so this
/// fetches each catalog once and filters client-side by keyword — honest
/// given the catalog sizes involved, no results are invented.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<dynamic> _universities = [];
  List<dynamic> _programs = [];
  List<dynamic> _countries = [];
  List<dynamic> _faqs = [];
  List<dynamic> _articles = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('global_search');
    _loadAll();
    _controller.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted)
          setState(() => _query = _controller.text.trim().toLowerCase());
      });
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        CatalogRepository.instance.getUniversities(),
        CatalogRepository.instance.getPrograms(),
        CatalogRepository.instance.getCountries(),
        CatalogRepository.instance.getFaqs(),
        CatalogRepository.instance.getArticles(),
      ]);
      if (!mounted) return;
      setState(() {
        _universities = results[0];
        _programs = results[1];
        _countries = results[2];
        _faqs = results[3];
        _articles = results[4];
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل بيانات البحث. تحقق من الاتصال وحاول مجددًا.';
        });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _matches(String? text) =>
      text != null && text.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final showResults = _query.length >= 2;
    final matchedUniversities = showResults
        ? _universities
            .where(
                (u) => _matches((u as Map<String, dynamic>)['name'] as String?))
            .toList()
        : [];
    final matchedPrograms = showResults
        ? _programs
            .where((p) =>
                _matches((p as Map<String, dynamic>)['title'] as String?))
            .toList()
        : [];
    final matchedCountries = showResults
        ? _countries
            .where(
                (c) => _matches((c as Map<String, dynamic>)['name'] as String?))
            .toList()
        : [];
    final matchedFaqs = showResults
        ? _faqs
            .where((f) =>
                _matches((f as Map<String, dynamic>)['question'] as String?))
            .toList()
        : [];
    final matchedArticles = showResults
        ? _articles
            .where((a) {
              final m = a as Map<String, dynamic>;
              return _matches(m['title'] as String?) ||
                  _matches(m['summary'] as String?);
            })
            .toList()
        : [];
    final totalMatches = matchedUniversities.length +
        matchedPrograms.length +
        matchedCountries.length +
        matchedFaqs.length +
        matchedArticles.length;

    return AppScaffold(
      title: 'البحث',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن جامعة، برنامج، دولة، مقال...',
                  hintStyle:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.navy),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(
                child: LoadingState(message: 'جاري تحميل بيانات البحث...'))
          else if (_error != null)
            Expanded(child: ErrorState(message: _error!, onRetry: _loadAll))
          else if (!showResults)
            const Expanded(
              child: Center(
                  child: Text('اكتب حرفين على الأقل للبحث',
                      style: AppTextStyles.caption)),
            )
          else if (totalMatches == 0)
            const Expanded(
                child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج',
                    message: 'جرّب كلمة بحث مختلفة.'))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (matchedUniversities.isNotEmpty)
                    _section(
                        'الجامعات',
                        matchedUniversities.map((u) {
                          final uni = u as Map<String, dynamic>;
                          return _ResultTile(
                            icon: Icons.account_balance_rounded,
                            title: uni['name'] as String? ?? '—',
                            subtitle: uni['city'] as String? ?? '',
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => UniversityDetailScreen(
                                        universityId: uni['_id'] as String,
                                        initialData: uni))),
                          );
                        }).toList()),
                  if (matchedPrograms.isNotEmpty)
                    _section(
                        'البرامج',
                        matchedPrograms.map((p) {
                          final program = p as Map<String, dynamic>;
                          return _ResultTile(
                            icon: Icons.menu_book_rounded,
                            title: program['title'] as String? ?? '—',
                            subtitle: program['degreeLevel'] as String? ?? '',
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => ProgramDetailScreen(
                                        programId: program['_id'] as String,
                                        initialData: program))),
                          );
                        }).toList()),
                  if (matchedCountries.isNotEmpty)
                    _section(
                        'الدول',
                        matchedCountries.map((c) {
                          final country = c as Map<String, dynamic>;
                          return _ResultTile(
                            icon: Icons.public_rounded,
                            title: country['name'] as String? ?? '—',
                            subtitle:
                                '${country['universityCount'] ?? 0} جامعة',
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        CountryDetailScreen(country: country))),
                          );
                        }).toList()),
                  if (matchedFaqs.isNotEmpty)
                    _section(
                        'الأسئلة الشائعة',
                        matchedFaqs.map((f) {
                          final faq = f as Map<String, dynamic>;
                          return _ResultTile(
                            icon: Icons.help_outline_rounded,
                            title: faq['question'] as String? ?? '—',
                            subtitle: 'الأسئلة الشائعة',
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const FaqScreen())),
                          );
                        }).toList()),
                  if (matchedArticles.isNotEmpty)
                    _section(
                        'المقالات',
                        matchedArticles.map((a) {
                          final article = Map<String, dynamic>.from(a as Map);
                          return _ResultTile(
                            icon: Icons.article_outlined,
                            title: article['title'] as String? ?? '—',
                            subtitle: article['summary'] as String? ?? 'مقال',
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ExhibitionArticleScreen(item: article))),
                          );
                        }).toList()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String label, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(label, style: AppTextStyles.sectionLabel)),
        ...items,
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ResultTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: AppColors.navy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
