import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_language.dart';

void main() {
  tearDown(() => CatalogLanguage.instance.english = false);

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
