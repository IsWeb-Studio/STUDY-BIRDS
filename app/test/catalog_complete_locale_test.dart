import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_language.dart';
import 'package:study_birds/screens/universities_programs_countries/universities_screens.dart';
import 'package:study_birds/screens/universities_programs_countries/programs_screens.dart';
import 'package:study_birds/screens/universities_programs_countries/compare_list_screen.dart';
import 'catalog_filters_test.dart' show mount;

void expectEnglish(WidgetTester tester) {
  final arabic = RegExp('[ء-ي]');
  final mixed = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .where((t) => arabic.hasMatch(t) && t != 'عربي').toList();
  expect(mixed, isEmpty, reason: 'English catalog must not contain Arabic UI');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CatalogLanguage.instance.english = true;
    CatalogLanguage.translationEnabled = false;
  });
  testWidgets('university details and open filters follow the top language switch', (tester) async {
    final country = {'name': 'Turkey', 'nameAr': 'تركيا'};
    final uni = {'_id': 'u', 'name': 'جامعة الاختبار', 'nameEn': 'Test University',
      'country': country, 'city': 'Istanbul', 'language': 'الإنجليزية'};
    final program = {'_id': 'p', 'title': 'الطب', 'titleEn': 'Medicine',
      'university': uni, 'degreeLevel': 'بكالوريوس', 'language': 'الإنجليزية',
      'requirements': ['الإنجليزية'], 'summary': 'نبذة', 'summaryEn': 'About medicine'};
    await http.runWithClient(() async {
      await mount(tester, const UniversitiesExplorerScreen());
      expectEnglish(tester);
      await tester.tap(find.text('Test University'));
      await tester.pumpAndSettle();
      expect(find.text('University details'), findsOneWidget);
      expectEnglish(tester);
      await tester.tap(find.text('Programs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter results'));
      await tester.pumpAndSettle();
      expectEnglish(tester);
      await tester.tap(find.text('عربي').last);
      await tester.pumpAndSettle();
      expect(find.text('تصفية النتائج'), findsOneWidget);
      expect(find.text('الدرجة العلمية'), findsOneWidget);
      await tester.tap(find.text('EN').last);
      await tester.pumpAndSettle();
      expect(find.text('Filter results'), findsOneWidget);
      expectEnglish(tester);
      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicine'));
      await tester.pumpAndSettle();
      expect(find.text('Program details'), findsOneWidget);
      expectEnglish(tester);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((r) async {
      final dynamic data = r.url.path.endsWith('/universities') ? [uni]
          : r.url.path.endsWith('/countries') ? [country]
          : r.url.path.endsWith('/programs') ? [program]
          : r.url.path.endsWith('/programs/p') ? program : uni;
      return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });

  testWidgets('orientation labels and stored choices switch without network translation', (tester) async {
    await mount(tester, const ProgramOrientationScreen());
    expectEnglish(tester);
    expect(find.text('Medicine and health'), findsOneWidget);
    await tester.tap(find.text('عربي'));
    await tester.pumpAndSettle();
    expect(find.text('الطب والصحة'), findsOneWidget);
    await tester.tap(find.text('الطب والصحة'));
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expectEnglish(tester);
    expect(find.text('Medicine and health'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hospital or clinic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expectEnglish(tester);
    expect(find.text('Balanced (theory and practice)'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expectEnglish(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('university comparison uses the same language', (tester) async {
    await http.runWithClient(() async {
      await mount(tester, const CompareListScreen());
      expect(find.text('Compare universities'), findsOneWidget);
      expectEnglish(tester);
      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();
      expect(find.text('مقارنة الجامعات'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
    }, () => MockClient((_) async => http.Response(jsonEncode([
      {'_id': 'u', 'name': 'الجامعة', 'nameEn': 'University', 'city': 'Istanbul',
        'country': {'name': 'Turkey', 'nameAr': 'تركيا'}}
    ]), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
