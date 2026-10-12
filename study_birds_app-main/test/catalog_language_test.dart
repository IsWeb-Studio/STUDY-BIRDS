import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_language.dart';

void main() {
  CatalogLanguage.translationEnabled = false;
  tearDown(() => CatalogLanguage.instance.english = false);
  translationFlow();

  test('names follow the catalog language with fallback', () {
    final uni = {'name': 'جامعة إسطنبول', 'nameEn': 'Istanbul University'};
    expect(catalogName(uni, 'name'), 'جامعة إسطنبول');
    CatalogLanguage.instance.english = true;
    expect(catalogName(uni, 'name'), 'Istanbul University');
    expect(catalogName({'name': 'جامعة'}, 'name'), 'جامعة');
  });

  test('country, article and stored values are localized', () {
    final country = {'name': 'Turkey', 'nameAr': 'تركيا'};
    expect(catalogCountryName(country), 'تركيا');
    final row = {
      'articleHeadings': ['عنوان'],
      'articleHeadingsEn': ['Heading'],
      'overview': 'نبذة'
    };
    expect(catalogLocalizedList(row, 'articleHeadings'), ['عنوان']);
    CatalogLanguage.instance.english = true;
    expect(catalogCountryName(country), 'Turkey');
    expect(catalogLocalizedList(row, 'articleHeadings'), ['Heading']);
    expect(catalogLocalizedText(row, 'overview'), 'نبذة');
    expect(catalogValue('بكالوريوس'), 'Bachelor');
    expect(catalogValue('Fall 2026'), 'Fall 2026');
    CatalogLanguage.instance.english = false;
    expect(catalogValue('Bachelor'), 'بكالوريوس');
    expect(catalogValue('Fall 2026'), 'خريف 2026');
    expect(catalogValue('4 years'), '4 سنوات');
  });
}

void translationFlow() {
  test('Arabic content without an English version is fetched from /translate',
      () async {
    CatalogLanguage.translationEnabled = true;
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      final lang = CatalogLanguage.instance..english = true;
      var notified = 0;
      lang.addListener(() => notified++);
      final row = {'name': 'جامعة أنقرة'};
      expect(catalogName(row, 'name'), 'جامعة أنقرة'); // original until it arrives
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(catalogName(row, 'name'), 'Ankara University');
      expect(notified, greaterThan(0));
      expect(requests, hasLength(1));
      catalogName(row, 'name'); // cached: no second request
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(requests, hasLength(1));
    }, () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          return http.Response(
              jsonEncode({
                'translations': [for (final _ in body['texts']) 'Ankara University']
              }),
              200,
              headers: {'content-type': 'application/json'});
        }));
    CatalogLanguage.translationEnabled = false;
  });
}
