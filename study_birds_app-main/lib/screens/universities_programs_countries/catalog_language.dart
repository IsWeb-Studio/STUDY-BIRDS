import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_theme.dart';

/// Language of the universities / programs pages (lists, filters, details).
/// Chosen by the user with the toggle in the app bar and remembered on device.
class CatalogLanguage extends ChangeNotifier {
  CatalogLanguage._();
  static final instance = CatalogLanguage._();
  static const _key = 'catalog_language_en';

  bool english = false;
  bool _loaded = false;

  TextDirection get direction =>
      english ? TextDirection.ltr : TextDirection.rtl;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key) ?? false;
      if (saved != english) {
        english = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    english = !english;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, english);
    } catch (_) {}
  }
}

/// Picks the Arabic or English text for the current catalog language.
String cl(String ar, String en) =>
    CatalogLanguage.instance.english ? en : ar;

String _text(dynamic value) => value is String ? value.trim() : '';

/// Name of a university / program in the current language. English falls back
/// to Arabic (and vice versa) when the other side has not been filled in.
String catalogName(Map<String, dynamic> row, String key) {
  final ar = _text(row['${key}Ar'] ?? row[key]);
  final en = _text(row['${key}En']);
  if (CatalogLanguage.instance.english) return en.isNotEmpty ? en : ar;
  return ar.isNotEmpty ? ar : en;
}

/// Country names are stored in `name` (English) with an optional `nameAr`.
String catalogCountryName(Map<String, dynamic> country) {
  final base = _text(country['name']);
  if (CatalogLanguage.instance.english) {
    final en = _text(country['nameEn']);
    return en.isNotEmpty ? en : base;
  }
  final ar = _text(country['nameAr']);
  return ar.isNotEmpty ? ar : base;
}

/// Picks the list (article headings / bodies) matching the current language.
List<String> catalogLocalizedList(
    Map<String, dynamic> row, String key) {
  List<String> read(dynamic v) => v is List ? v.map((e) => '$e').toList() : [];
  final ar = read(row[key]);
  final en = read(row['${key}En']);
  bool has(List<String> l) => l.any((e) => e.trim().isNotEmpty);
  if (CatalogLanguage.instance.english) return has(en) ? en : ar;
  return has(ar) ? ar : en;
}

/// Picks a single text field (overview, summary, article title).
String catalogLocalizedText(Map<String, dynamic> row, String key) {
  final ar = _text(row[key]);
  final en = _text(row['${key}En']);
  if (CatalogLanguage.instance.english) return en.isNotEmpty ? en : ar;
  return ar.isNotEmpty ? ar : en;
}

const _pairs = <List<String>>[
  // degree levels
  ['Technical Institute', 'معهد تقني'],
  ['Bachelor', 'بكالوريوس'],
  ['Postgraduate Diploma', 'دبلوم دراسات عليا'],
  ['Non-Thesis Master', 'ماجستير بدون رسالة'],
  ['Thesis Master', 'ماجستير برسالة'],
  ['Professional Doctorate', 'دكتوراه مهنية'],
  ['PhD', 'دكتوراه'],
  ['Postdoctoral', 'ما بعد الدكتوراه'],
  ['Master', 'ماجستير'],
  ['Diploma', 'دبلوم'],
  // study languages
  ['Arabic', 'العربية'],
  ['Turkish', 'التركية'],
  ['30% English + 70% Turkish', '30% إنجليزي + 70% تركي'],
  ['30% Turkish + 70% English', '30% تركي + 70% إنجليزي'],
  ['Russian', 'الروسية'],
  ['Uzbek', 'الأوزبكية'],
  ['English', 'الإنجليزية'],
  ['German', 'الألمانية'],
  ['Italian', 'الإيطالية'],
  ['Polish', 'البولندية'],
  ['Dutch', 'الهولندية'],
  ['French', 'الفرنسية'],
  ['Spanish', 'الإسبانية'],
  ['Portuguese', 'البرتغالية'],
  ['Hungarian', 'المجرية'],
  ['Czech', 'التشيكية'],
  ['Romanian', 'الرومانية'],
  ['Chinese', 'الصينية'],
  ['Korean', 'الكورية'],
  ['Japanese', 'اليابانية'],
  // fields of study
  ['Technology', 'التكنولوجيا'],
  ['Business', 'الأعمال'],
  ['Engineering', 'الهندسة'],
  ['Social Sciences', 'العلوم الاجتماعية'],
  ['Medicine', 'الطب'],
  ['Computer Science', 'علوم الحاسوب'],
  ['Law', 'القانون'],
  ['Pharmacy', 'الصيدلة'],
  ['Dentistry', 'طب الأسنان'],
];

const _seasons = <List<String>>[
  ['Fall', 'خريف'],
  ['Spring', 'ربيع'],
  ['Summer', 'صيف'],
  ['Winter', 'شتاء'],
];

/// Translates a stored catalog value (degree, study language, field, intake,
/// duration) into the current language. Unknown values are returned as-is.
String catalogValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final en = CatalogLanguage.instance.english;
  final lower = value.toLowerCase();
  for (final p in _pairs) {
    if (lower == p[0].toLowerCase() || value == p[1]) return en ? p[0] : p[1];
  }
  for (final s in _seasons) {
    final m = RegExp('^(${s[0]}|${s[1]})\\s*(\\d{4})\$', caseSensitive: false)
        .firstMatch(value);
    if (m != null) return '${en ? s[0] : s[1]} ${m.group(2)}';
  }
  final years = RegExp(r'^(\d+(?:\.\d+)?)\s*(years?|سنوات|سنة)$',
          caseSensitive: false)
      .firstMatch(value);
  if (years != null) {
    final n = years.group(1)!;
    return en ? '$n ${n == '1' ? 'year' : 'years'}' : '$n ${n == '1' ? 'سنة' : 'سنوات'}';
  }
  return value;
}

/// عربي | EN switch shown in the app bar of the catalog pages.
class CatalogLanguageToggle extends StatelessWidget {
  const CatalogLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = CatalogLanguage.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: lang.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white54)),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.translate_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(lang.english ? 'عربي' : 'EN',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

/// Rebuilds [builder] whenever the catalog language changes.
class CatalogLanguageBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  const CatalogLanguageBuilder({super.key, required this.builder});
  @override
  State<CatalogLanguageBuilder> createState() => _CatalogLanguageBuilderState();
}

class _CatalogLanguageBuilderState extends State<CatalogLanguageBuilder> {
  @override
  void initState() {
    super.initState();
    CatalogLanguage.instance.addListener(_changed);
    CatalogLanguage.instance.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CatalogLanguage.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// App scaffold for catalog pages: follows the catalog language (title,
/// direction) and carries the language toggle.
class CatalogScaffold extends StatelessWidget {
  final String Function() title;
  final Widget body;
  final List<Widget> actions;
  const CatalogScaffold(
      {super.key,
      required this.title,
      required this.body,
      this.actions = const []});

  @override
  Widget build(BuildContext context) => CatalogLanguageBuilder(
      builder: (_) => AppScaffold(
          title: title(),
          textDirection: CatalogLanguage.instance.direction,
          actions: [...actions, const CatalogLanguageToggle()],
          body: body));
}
