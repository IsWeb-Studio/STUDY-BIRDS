import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_theme.dart';

/// Language of the universities / programs pages (lists, filters, details).
/// Chosen by the user with the toggle in the app bar and remembered on device.
class CatalogLanguage extends ChangeNotifier {
  CatalogLanguage._();
  static final instance = CatalogLanguage._();
  static const _key = 'catalog_language_en';

  /// The catalog pages (universities, programs, countries) are English by
  /// default; the user can switch to Arabic and back, and the choice is
  /// remembered. The rest of the app stays Arabic.
  bool english = true;
  bool _loaded = false;

  TextDirection get direction =>
      english ? TextDirection.ltr : TextDirection.rtl;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key) ?? true;
      if (saved != english) {
        english = saved;
        notifyListeners();
      }
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/universities_programs_countries/catalog_language.dart:load');
    }
  }

  // ── On-demand machine translation of catalog content, BOTH directions ───
  //  • English view: Arabic text with no hand-written English version → English
  //  • Arabic view:  English-only text (names, descriptions typed in English)
  //                  → Arabic
  // Text is sent to POST /translate (server caches results) with the wanted
  // `target`, and swapped in when it arrives. Keys are "<target>|<text>".
  static bool translationEnabled = true;
  static final _arabic = RegExp('[؀-ۿ]');
  static final _latin = RegExp('[A-Za-z]');
  final Map<String, String> _translated = {};
  final Set<String> _queued = {}, _inFlight = {}, _failed = {};
  Timer? _flushTimer;

  static String _key2(String target, String text) => '$target|$text';

  /// Whether [text] is in the *other* language and so needs translating.
  static bool needsTranslation(String text, String target) => target == 'en'
      ? _arabic.hasMatch(text)
      : _latin.hasMatch(text) && !_arabic.hasMatch(text);

  /// English text for [arabic]: the translation if known (otherwise the
  /// original, and a fetch is scheduled that re-notifies listeners).
  String tr(String arabic) => english ? _translate(arabic, 'en') : arabic;

  /// Arabic text for [english]-only content (used in the Arabic view).
  String trAr(String text) => english ? text : _translate(text, 'ar');

  String _translate(String original, String target) {
    final text = original.trim();
    if (text.isEmpty || !needsTranslation(text, target)) return original;
    final key = _key2(target, text);
    final known = _translated[key];
    if (known != null) return known;
    if (translationEnabled &&
        !_failed.contains(key) &&
        !_inFlight.contains(key) &&
        _queued.add(key)) {
      _flushTimer ??= Timer(const Duration(milliseconds: 150), _flush);
    }
    return original;
  }

  Future<void> _flush() async {
    _flushTimer = null;
    final pending = _queued.toList();
    _queued.clear();
    var changed = false;
    for (final target in const ['en', 'ar']) {
      final texts = pending
          .where((k) => k.startsWith('$target|'))
          .map((k) => k.substring(target.length + 1))
          .toList();
      var index = 0;
      while (index < texts.length) {
        // keep each request well under the server's body limit
        final batch = <String>[];
        var size = 0;
        while (index < texts.length &&
            batch.length < 40 &&
            (batch.isEmpty || size + texts[index].length < 50000)) {
          size += texts[index].length;
          batch.add(texts[index++]);
        }
        _inFlight.addAll(batch.map((t) => _key2(target, t)));
        try {
          final data = await ApiClient.instance
              .post('/translate', body: {'texts': batch, 'target': target});
          final list = data is Map ? data['translations'] : null;
          for (var i = 0; i < batch.length; i++) {
            final value = list is List && i < list.length ? list[i] : null;
            if (value is String && value.trim().isNotEmpty) {
              _translated[_key2(target, batch[i])] = value.trim();
              changed = true;
            }
          }
        } catch (swallowedError, swallowedStack) {
          // server translation unavailable (older deployment, offline, ...)
          ErrorReporter.swallowed(swallowedError, swallowedStack,
              'screens/universities_programs_countries/catalog_language.dart:flush');
        }
        // Anything the server did not translate goes straight to the public
        // translate endpoint so the page never stays in the wrong language.
        final missing = batch
            .where((t) => !_translated.containsKey(_key2(target, t)))
            .toList();
        await Future.wait(missing.map((text) async {
          final value = await _publicTranslate(text, target);
          if (value != null) {
            _translated[_key2(target, text)] = value;
            changed = true;
          } else {
            _failed.add(_key2(target, text));
          }
        }));
        _inFlight.removeAll(batch.map((t) => _key2(target, t)));
      }
    }
    if (changed) notifyListeners();
  }

  static List<String> _chunks(String text) {
    final chunks = <String>[];
    var current = '';
    for (final line in text.split('\n')) {
      if (current.isNotEmpty && current.length + line.length + 1 > 1200) {
        chunks.add(current);
        current = line;
      } else {
        current = current.isEmpty ? line : '$current\n$line';
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  Future<String?> _publicTranslate(String text, String target) async {
    try {
      final parts = <String>[];
      for (final chunk in _chunks(text)) {
        if (!needsTranslation(chunk, target)) {
          parts.add(chunk);
          continue;
        }
        final response = await http
            .post(
                Uri.https('translate.googleapis.com', '/translate_a/single', {
                  'client': 'gtx',
                  'sl': target == 'en' ? 'ar' : 'en',
                  'tl': target,
                  'dt': 't'
                }),
                body: {'q': chunk})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return null;
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is! List || data.isEmpty || data[0] is! List) return null;
        parts.add((Json.list(data[0]))
            .map((s) => s is List && s.isNotEmpty && s[0] is String ? s[0] : '')
            .join());
      }
      final result = parts.join('\n').trim();
      return result.isEmpty ? null : result;
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/universities_programs_countries/catalog_language.dart:public');
      return null;
    }
  }

  /// Test helper: forget cached translations and pending work.
  void resetTranslationsForTest() {
    _translated.clear();
    _queued.clear();
    _inFlight.clear();
    _failed.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  Future<void> toggle() async {
    english = !english;
    _failed.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, english);
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/universities_programs_countries/catalog_language.dart:toggle');
    }
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
  if (CatalogLanguage.instance.english) {
    return en.isNotEmpty ? en : CatalogLanguage.instance.tr(ar);
  }
  return CatalogLanguage.instance.trAr(ar.isNotEmpty ? ar : en);
}

/// Country names are stored in `name` (English) with an optional `nameAr`.
String catalogCountryName(Map<String, dynamic> country) {
  final base = _text(country['name']);
  if (CatalogLanguage.instance.english) {
    final en = _text(country['nameEn']);
    return en.isNotEmpty ? en : CatalogLanguage.instance.tr(base);
  }
  final ar = _text(country['nameAr']);
  return CatalogLanguage.instance.trAr(ar.isNotEmpty ? ar : base);
}

/// Picks the list (article headings / bodies) matching the current language.
List<String> catalogLocalizedList(
    Map<String, dynamic> row, String key) {
  List<String> read(dynamic v) => v is List ? v.map((e) => '$e').toList() : [];
  final ar = read(row[key]);
  final en = read(row['${key}En']);
  bool has(List<String> l) => l.any((e) => e.trim().isNotEmpty);
  if (CatalogLanguage.instance.english) {
    return has(en) ? en : ar.map(CatalogLanguage.instance.tr).toList();
  }
  return (has(ar) ? ar : en).map(CatalogLanguage.instance.trAr).toList();
}

/// Picks a single text field (overview, summary, article title).
String catalogLocalizedText(Map<String, dynamic> row, String key) {
  final ar = _text(row[key]);
  final en = _text(row['${key}En']);
  if (CatalogLanguage.instance.english) {
    return en.isNotEmpty ? en : CatalogLanguage.instance.tr(ar);
  }
  return CatalogLanguage.instance.trAr(ar.isNotEmpty ? ar : en);
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
  return en ? CatalogLanguage.instance.tr(value) : CatalogLanguage.instance.trAr(value);
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
