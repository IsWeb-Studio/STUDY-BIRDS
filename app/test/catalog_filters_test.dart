import 'package:study_birds/screens/universities_programs_countries/catalog_language.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_detail.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_browser.dart';
import 'package:study_birds/screens/universities_programs_countries/programs_screens.dart';
import 'package:study_birds/screens/universities_programs_countries/universities_screens.dart';

final university = <String, dynamic>{
  '_id': 'u1',
  'name': 'جامعة إسطنبول',
  'city': 'إسطنبول',
  'country': {'name': 'تركيا'},
  'language': 'التركية',
  'isPartnerInstitution': true,
  'tuitionRange': {'min': 2000}
};
final programs = <Map<String, dynamic>>[
  {
    '_id': 'p1',
    'title': 'هندسة البرمجيات',
    'university': university,
    'degreeLevel': 'بكالوريوس',
    'language': 'الإنجليزية',
    'fieldOfStudy': 'الهندسة',
    'fieldsOfStudy': ['الحاسوب'],
    'tuition': 2000,
    'duration': '4 سنوات',
    'intake': 'سبتمبر'
  },
  {
    '_id': 'p2',
    'title': 'إدارة الأعمال',
    'university': university,
    'degreeLevel': 'ماجستير',
    'language': 'التركية',
    'fieldOfStudy': 'الإدارة',
    'tuition': 4000,
    'duration': 'سنتان'
  },
  {
    '_id': 'p3',
    'title': 'علوم البيانات',
    'university': university,
    'degreeLevel': 'ماجستير',
    'language': 'الإنجليزية',
    'fieldOfStudy': 'الحاسوب'
  },
];
final boundaryKey = GlobalKey();
Future<void> preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CATALOG_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('integration/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> mount(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: home)));
  await tester.pumpAndSettle();
}

void main() {
  // These tests exercise the Arabic view; the catalog is English by default.
  setUp(() => CatalogLanguage.instance.english = false);
  setUpAll(() async {
    final loader = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test(
      'facets combine, multiple fields match, unknown fees are excluded only by budget',
      () {
    expect(
        filterCatalog(
                programs,
                const CatalogSelection(facets: {
                  'fieldOfStudy': 'الحاسوب',
                  'language': 'الإنجليزية'
                }, maxTuition: 2500),
                '',
                false)
            .map((p) => p['_id']),
        ['p1']);
    expect(
        filterCatalog(programs, const CatalogSelection(sort: 'fee'), '', false)
            .map((p) => p['_id']),
        ['p1', 'p2', 'p3']);
    expect(
        filterCatalog(programs, const CatalogSelection(), 'إسطنبول', false)
            .length,
        3);
    expect(
        filterCatalog([
          university,
          {
            'name': 'Other',
            'tuitionRange': {'min': 1000}
          }
        ], const CatalogSelection(partnerOnly: true, maxTuition: 2500), '',
                true)
            .length,
        1);
  });
  testWidgets(
      'finder filter applies Arabic budget, cancel discards changes, reset restores results',
      (tester) async {
    await http.runWithClient(() async {
      await mount(tester, const ProgramFinderScreen());
      expect(find.text('هندسة البرمجيات'), findsOneWidget);
      await preview(tester, 'catalog-finder');
      await tester.tap(find.byTooltip('تصفية النتائج'));
      await tester.pumpAndSettle();
      await preview(tester, 'catalog-filters');
      final budget = find.byType(TextFormField);
      await tester.ensureVisible(budget);
      await tester.pumpAndSettle();
      await tester.enterText(budget, '٢٬٥٠٠');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('إغلاق الفلاتر'));
      await tester.pumpAndSettle();
      expect(find.text('3 برنامج'), findsOneWidget);
      await tester.tap(find.byTooltip('تصفية النتائج'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(budget);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(budget).controller!.text, isEmpty);
      await tester.enterText(budget, '٢٬٥٠٠');
      await tester.pumpAndSettle();
      await tester.tap(find.text('عرض النتائج (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 برنامج من 3'), findsOneWidget);
      expect(find.text('إدارة الأعمال'), findsNothing);
      await preview(tester, 'catalog-filtered');
      await tester.tap(find.text('مسح الكل'));
      await tester.pumpAndSettle();
      expect(find.text('3 برنامج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => http.Response(jsonEncode(programs), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
  testWidgets(
      'university listing and its programs expose filters and scope requests',
      (tester) async {
    var scoped = false;
    await http.runWithClient(() async {
      await mount(
          tester, const UniversitiesExplorerScreen(countryId: 'turkey'));
      expect(find.byTooltip('تصفية النتائج'), findsOneWidget);
      await preview(tester, 'catalog-universities');
      await tester.tap(find.text('جامعة إسطنبول'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('البرامج'));
      await tester.pumpAndSettle();
      expect(scoped, isTrue);
      expect(find.byTooltip('تصفية النتائج'), findsOneWidget);
      await preview(tester, 'catalog-university-programs');
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              dynamic data;
              if (r.url.path.endsWith('/programs')) {
                expect(r.url.queryParameters['university'], 'u1');
                scoped = true;
                data = programs;
              } else if (r.url.path.endsWith('/universities')) {
                expect(r.url.queryParameters['country'], isNull);
                data = [university];
              } else if (r.url.path.endsWith('/content/countries')) {
                data = [
                  {'_id': 'turkey', 'name': 'تركيا'},
                  {'_id': 'germany', 'name': 'ألمانيا'}
                ];
              } else {
                data = university;
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets(
      'country choices include empty countries and changing country clears dependent university',
      (tester) async {
    final other = <String, dynamic>{
      '_id': 'u2',
      'name': 'جامعة برلين',
      'country': {'name': 'ألمانيا'},
      'city': 'برلين'
    };
    final countries = [
      {'_id': 'tr', 'name': 'تركيا'},
      {'_id': 'de', 'name': 'ألمانيا'},
      {'_id': 'jp', 'name': 'اليابان'}
    ];
    Finder dropdown(String label) => find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<String> &&
        w.decoration.labelText == label);
    await http.runWithClient(() async {
      await mount(tester, const ProgramsExplorerScreen());
      await tester.tap(find.byTooltip('تصفية النتائج'));
      await tester.pumpAndSettle();
      Future<void> choose(String label, String value) async {
        await Scrollable.ensureVisible(tester.element(dropdown(label)),
            alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(dropdown(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      expect(
          tester
              .widget<DropdownButton<String>>(find.descendant(
                  of: dropdown('الدولة'),
                  matching: find.byType(DropdownButton<String>)))
              .items!
              .map((e) => e.value),
          contains('اليابان'));
      await choose('الدولة', 'تركيا');
      expect(
          tester
              .widget<DropdownButton<String>>(find.descendant(
                  of: dropdown('الجامعة'),
                  matching: find.byType(DropdownButton<String>)))
              .items!
              .map((e) => e.value),
          ['', 'جامعة إسطنبول']);
      await choose('الجامعة', 'جامعة إسطنبول');
      await choose('الدولة', 'ألمانيا');
      final uniMenu =
          tester.widget<DropdownButtonFormField<String>>(dropdown('الجامعة'));
      expect(uniMenu.initialValue, '');
      expect(
          tester
              .widget<DropdownButton<String>>(find.descendant(
                  of: dropdown('الجامعة'),
                  matching: find.byType(DropdownButton<String>)))
              .items!
              .map((e) => e.value),
          ['', 'جامعة برلين']);
      await choose('الدولة', 'اليابان');
      expect(
          tester
              .widget<DropdownButton<String>>(find.descendant(
                  of: dropdown('الجامعة'),
                  matching: find.byType(DropdownButton<String>)))
              .items!
              .length,
          1);
      await preview(tester, 'catalog-cascading-filters');
      await tester.tap(find.text('عرض النتائج (0)'));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => http.Response(
            jsonEncode(r.url.path.endsWith('/countries')
                ? countries
                : r.url.path.endsWith('/universities')
                    ? [university, other]
                    : programs),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
  test('dependent program facets respect university and field parents', () {
    final rows = [
      ...programs,
      {
        'title': 'طب',
        'university': {
          'name': 'جامعة أخرى',
          'country': {'name': 'ألمانيا'}
        },
        'fieldOfStudy': 'الطب',
        'degreeLevel': 'دكتوراه'
      }
    ];
    const order = [
      'country',
      'university',
      'fieldOfStudy',
      'degreeLevel',
      'language'
    ];
    expect(
        catalogFacetOptions(
            'fieldOfStudy',
            order,
            {'country': 'تركيا', 'university': 'جامعة إسطنبول'},
            rows,
            [],
            [university],
            false),
        isNot(contains('الطب')));
    expect(
        catalogFacetOptions(
            'degreeLevel',
            order,
            {'country': 'تركيا', 'fieldOfStudy': 'الإدارة'},
            rows,
            [],
            [university],
            false),
        ['ماجستير']);
    expect(catalogAssetUrl('/uploads/photo.webp'),
        'https://study-birds1.onrender.com/uploads/photo.webp');
    expect(catalogAssetUrl('javascript:alert(1)'), isNull);
    expect(
        catalogImages({
          'coverImage': '/cover.jpg',
          'university': {
            'campusImages': ['/campus.jpg']
          }
        }, false),
        [
          'https://study-birds1.onrender.com/cover.jpg',
          'https://study-birds1.onrender.com/campus.jpg'
        ]);
  });
  testWidgets(
      'detail uses full API article, all bodies and images rather than list summary',
      (tester) async {
    final detail = {
      ...programs.first,
      'summary': 'نبذة البرنامج من السيرفر',
      'coverImage': 'https://example.test/cover.jpg',
      'articleTitle': 'دليل هندسة البرمجيات',
      'articleHeadings': ['خطة الدراسة', '', 'فرص العمل'],
      'articleBodies': [
        'محتوى الخطة',
        'فقرة بدون عنوان',
        'محتوى الفرص',
        'فقرة إضافية من السيرفر'
      ]
    };
    await http.runWithClient(() async {
      await mount(tester,
          ProgramDetailScreen(programId: 'p1', initialData: programs.first));
      expect(find.byType(Image), findsWidgets);
      // Catalog images go through the cached image widget (CachedNetworkImage).
      expect(
          tester
              .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .any((w) => w.imageUrl == 'https://example.test/cover.jpg'),
          isTrue);
      await preview(tester, 'catalog-program-detail');
      await tester.scrollUntilVisible(find.text('دليل هندسة البرمجيات'), 350,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await preview(tester, 'catalog-program-article');
      await tester.scrollUntilVisible(find.text('فقرة إضافية من السيرفر'), 250,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('فقرة بدون عنوان'), findsOneWidget);
      expect(find.text('فقرة إضافية من السيرفر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => http.Response(jsonEncode(detail), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
  testWidgets(
      'university detail renders campus gallery, server facts and article',
      (tester) async {
    final detail = {
      ...university,
      'overview': 'نبذة الجامعة من السيرفر',
      'studentCount': 12000,
      'specialtyCount': 45,
      'campusImages': [
        'https://example.test/campus1.jpg',
        'https://example.test/campus2.jpg'
      ],
      'articleTitle': 'الدراسة في الجامعة',
      'articleHeadings': ['الحياة الجامعية'],
      'articleBodies': ['مقال الجامعة من السيرفر']
    };
    await http.runWithClient(() async {
      await mount(tester,
          UniversityDetailScreen(universityId: 'u1', initialData: university));
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await preview(tester, 'catalog-university-detail');
      await tester.scrollUntilVisible(find.text('مقال الجامعة من السيرفر'), 300,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await preview(tester, 'catalog-university-article');
      expect(find.text('الحياة الجامعية'), findsOneWidget);
      expect(find.text('12000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => http.Response(
            jsonEncode(r.url.path.endsWith('/universities/u1')
                ? detail
                : r.url.path.endsWith('/countries')
                    ? [
                        {'name': 'تركيا'}
                      ]
                    : r.url.path.endsWith('/universities')
                        ? [university]
                        : programs),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
