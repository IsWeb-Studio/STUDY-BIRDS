import 'package:study_birds/core/utils/app_error.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/connected/connected_app.dart';
import 'package:study_birds/core/network/study_birds_api.dart';

void main() {
  testWidgets('comparison displays current prices for selected favorites',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: FavoritesComparison(favorites: [
      {
        '_id': 'a',
        'program': {
          'title': 'Program A',
          'tuition': 1200,
          'university': {
            'name': 'University A',
            'country': {'name': 'Country A'}
          }
        }
      },
      {
        '_id': 'b',
        'program': {
          'title': 'Program B',
          'tuition': 2500,
          'university': {
            'name': 'University B',
            'country': {'name': 'Country B'}
          }
        }
      },
    ])));
    expect(find.byType(DataTable), findsNothing);
    await tester.tap(find.text('Program A'));
    await tester.pump();
    await tester.tap(find.text('Program B'));
    await tester.pump();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('2500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('remote module titles and visibility control student home',
      (tester) async {
    final api = StudyBirdsApi();
    api.user = {'name': 'طالب', 'role': 'student'};
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(
        home:
            ConnectedHome(api: api, refreshConfig: () async {}, config: const {
      'title': 'Study Birds',
      'welcome': 'أهلاً',
      'banners': [],
      'modules': [
        {
          'key': 'programs',
          'title': 'تخصصات مميزة',
          'enabled': true,
          'order': 1
        },
        {
          'key': 'universities',
          'title': 'قسم مخفي',
          'enabled': false,
          'order': 0
        },
        {
          'key': 'partner-wallet',
          'title': 'رصيد الوكيل',
          'enabled': true,
          'order': 2
        },
      ],
    })));
    expect(find.text('تخصصات مميزة'), findsOneWidget);
    expect(find.text('قسم مخفي'), findsNothing);
    expect(find.text('رصيد الوكيل'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('partner navigation respects remote configuration',
      (tester) async {
    final api = StudyBirdsApi();
    api.user = {'name': 'وكيل', 'role': 'partner'};
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(
        home:
            ConnectedHome(api: api, refreshConfig: () async {}, config: const {
      'title': 'Study Birds',
      'welcome': 'أهلاً',
      'banners': [],
      'modules': [
        {
          'key': 'partner-wallet',
          'title': 'أرباحي',
          'enabled': true,
          'order': 1
        },
        {
          'key': 'partner-profile',
          'title': 'مخفي',
          'enabled': false,
          'order': 2
        },
      ],
    })));
    expect(find.text('أرباحي'), findsOneWidget);
    expect(find.text('مخفي'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('service detail submits a real request with content ID',
      (tester) async {
    http.Request? submitted;
    final api = StudyBirdsApi(client: MockClient((request) async {
      submitted = request;
      return http.Response('{}', 201);
    }));
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ResourceDetail(api: api, kind: 'services', item: const {
      '_id': 'service-1',
      'title': 'استشارة',
      'body': 'تفاصيل',
      'requestable': true
    })));
    await tester.tap(find.text('طلب الخدمة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'أريد موعداً غداً');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(submitted!.method, 'POST');
    expect(submitted!.url.path, endsWith('/mobile/requests'));
    expect(jsonDecode(submitted!.body),
        {'message': 'أريد موعداً غداً', 'contentId': 'service-1'});
    expect(tester.takeException(), isNull);
  });
  testWidgets('applications require the three mandatory document types',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: ApplicationDocuments(documents: [
      {'_id': '1', 'fileName': 'Passport', 'type': 'passport'},
      {'_id': '2', 'fileName': 'Photo', 'type': 'biometric-photo'},
      {'_id': '3', 'fileName': 'Diploma', 'type': 'latest-qualification'},
    ])));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    for (final label in ['Passport', 'Photo', 'Diploma']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
  testWidgets('server errors offer retry without showing demo records',
      (tester) async {
    var calls = 0;
    final api = StudyBirdsApi(client: MockClient((_) async {
      calls++;
      return calls == 1
          ? http.Response('{"message":"Unavailable"}', 503)
          : http.Response('[]', 200);
    }));
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ResourceScreen(
            api: api,
            title: 'طلباتي',
            kind: 'applications',
            path: '/students/applications')));
    await tester.pumpAndSettle();
    // Raw server text is never shown; a 503 maps to the safe unavailable message.
    expect(find.text('Unavailable'), findsNothing);
    expect(find.text(AppError.unavailable), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج حالياً'), findsOneWidget);
    expect(calls, 2);
  });
}
