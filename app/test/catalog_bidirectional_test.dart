import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_language.dart';

/// The universities / programs pages: English by default, switchable to Arabic
/// and back, with content translated in BOTH directions.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CatalogLanguage.translationEnabled = true;
    CatalogLanguage.instance.resetTranslationsForTest();
  });
  tearDown(() {
    CatalogLanguage.translationEnabled = false;
    CatalogLanguage.instance.resetTranslationsForTest();
  });

  test('first launch: the catalog pages are English (LTR)', () async {
    final lang = CatalogLanguage.instance;
    lang.english = true; // the singleton's initial value
    await lang.load();
    expect(lang.english, isTrue);
    expect(lang.direction.name, 'ltr');
  });

  test('the choice is remembered, in both directions', () async {
    final lang = CatalogLanguage.instance..english = true;
    await lang.toggle(); // -> Arabic
    expect(lang.english, isFalse);
    expect(lang.direction.name, 'rtl');
    expect(
        (await SharedPreferences.getInstance()).getBool('catalog_language_en'),
        isFalse);
    await lang.toggle(); // -> English again
    expect(lang.english, isTrue);
    expect(
        (await SharedPreferences.getInstance()).getBool('catalog_language_en'),
        isTrue);
  });

  test('which text needs translating depends on the direction', () {
    expect(CatalogLanguage.needsTranslation('جامعة إسطنبول', 'en'), isTrue);
    expect(
        CatalogLanguage.needsTranslation('Istanbul University', 'en'), isFalse);
    expect(
        CatalogLanguage.needsTranslation('Istanbul University', 'ar'), isTrue);
    expect(CatalogLanguage.needsTranslation('جامعة إسطنبول', 'ar'), isFalse);
    expect(CatalogLanguage.needsTranslation('2026', 'ar'), isFalse);
  });

  test('Arabic view: English-only content is fetched as Arabic', () async {
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      final lang = CatalogLanguage.instance..english = false;
      var notified = 0;
      lang.addListener(() => notified++);
      // A university whose name/description exist only in English.
      final uni = {
        'nameEn': 'Istanbul University',
        'overviewEn': 'A leading university'
      };
      expect(catalogName(uni, 'name'), uni['nameEn'] ?? uni['name']);
      expect(catalogLocalizedText(uni, 'overview'), uni['overviewEn']);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(catalogName(uni, 'name'), 'ترجمة Istanbul University');
      expect(
          catalogLocalizedText(uni, 'overview'), 'ترجمة A leading university');
      expect(notified, greaterThan(0),
          reason: 'screens rebuild when it arrives');
    },
        () => MockClient((r) async {
              final body = jsonDecode(r.body) as Map<String, dynamic>;
              requests.add(body);
              return http.Response(
                  jsonEncode({
                    'translations': [
                      for (final t in body['texts'])
                        body['target'] == 'ar'
                            ? 'ترجمة $t'
                            : 'Translated content'
                    ]
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
    expect(requests.every((b) => b['target'] == 'ar'), isTrue);
  });

  test('English view: Arabic-only content is still fetched as English',
      () async {
    await http.runWithClient(() async {
      final lang = CatalogLanguage.instance..english = true;
      final uni = {'name': 'جامعة إسطنبول'};
      expect(catalogName(uni, 'name'), uni['nameEn'] ?? uni['name']);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(catalogName(uni, 'name'), 'Istanbul University');
      expect(lang.english, isTrue);
    },
        () => MockClient((r) async {
              final body = jsonDecode(r.body) as Map<String, dynamic>;
              return http.Response(
                  jsonEncode({
                    'translations': [
                      for (final _ in body['texts']) 'Istanbul University'
                    ]
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  test('hand-written text in the wanted language is never sent for translation',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      final lang = CatalogLanguage.instance..english = false;
      expect(catalogName({'nameAr': 'جامعة', 'nameEn': 'University'}, 'name'),
          'جامعة');
      lang.english = true;
      expect(catalogName({'nameAr': 'جامعة', 'nameEn': 'University'}, 'name'),
          'University');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    },
        () => MockClient((r) async {
              calls++;
              return http.Response('{}', 200);
            }));
    expect(calls, 0);
  });

  test(
      'Arabic view never leaves English-only content blank when translation fails',
      () async {
    await http.runWithClient(() async {
      CatalogLanguage.instance.english = false;
      final uni = {'nameEn': 'Medical School'};
      expect(catalogName(uni, 'name'), uni['nameEn'] ?? uni['name']);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(catalogName(uni, 'name'), uni['nameEn'] ?? uni['name']);
    }, () => MockClient((r) async => throw http.ClientException('offline')));
  });
}
