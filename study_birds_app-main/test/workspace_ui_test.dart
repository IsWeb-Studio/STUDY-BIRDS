import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:study_birds/connected/connected_app.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/study_birds_api.dart';
import 'package:study_birds/screens/auth/onboarding_and_account_type_screens.dart';

const preview = bool.fromEnvironment('WRITE_UI_PREVIEWS');
Future<void> fonts() async {
  if (!preview) return;
  for (final entry in {
    'PreviewArabic': 'C:/Windows/Fonts/tahoma.ttf',
    'MaterialIcons':
        'D:/fluter/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf'
  }.entries) {
    final file = File(entry.value);
    if (file.existsSync()) {
      await (FontLoader(entry.key)
            ..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync()))))
          .load();
    }
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!preview) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('integration/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget app(Widget home, GlobalKey key) => RepaintBoundary(
    key: key,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            fontFamily: preview ? 'PreviewArabic' : null,
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.navy, foregroundColor: Colors.white),
            colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.navy, primary: AppColors.navy)),
        home: home));
void main() {
  testWidgets('two-factor login asks for code before creating a session',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = StudyBirdsApi(client: MockClient((request) async {
      final body = jsonDecode(request.body);
      if (body['twoFactorCode'] != '123456')
        return http.Response('{"message":"Enter email code"}', 428);
      return http.Response(
          '{"token":"session","user":{"role":"student"}}', 200);
    }));
    addTearDown(api.dispose);
    await tester.pumpWidget(app(
        ConnectedLogin(api: api, title: 'Study Birds', accountRole: 'student'),
        GlobalKey()));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'student@example.test');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'TestPassword123!');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(api.authenticated, isFalse);
    expect(find.text('رمز التحقق من البريد'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(api.authenticated, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'three step student setup saves actual fields and retains names containing T',
      (tester) async {
    Map<String, dynamic>? saved;
    bool completed = false;
    final api = StudyBirdsApi(client: MockClient((request) async {
      if (request.method == 'PUT') {
        saved = jsonDecode(request.body);
      }
      return http.Response(
          '{"englishFullName":"Tarek Test","currentEducation":"School","targetCountries":["Turkey"]}',
          200);
    }));
    addTearDown(api.dispose);
    await tester.pumpWidget(app(
        StudentSetupWizard(api: api, onDone: () => completed = true),
        GlobalKey()));
    await tester.pumpAndSettle();
    expect(find.text('Tarek Test'), findsOneWidget);
    await tester.ensureVisible(find.text('التالي'));
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('التالي'));
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('حفظ وبدء الرحلة'));
    await tester.tap(find.text('حفظ وبدء الرحلة'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(saved?['englishFullName'], 'Tarek Test');
    expect(saved?['targetCountries'], ['Turkey']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('all five account types are selectable including employee',
      (tester) async {
    await fonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    final key = GlobalKey();
    await tester.pumpWidget(app(
        AccountTypeSelectionScreen(onSelected: (type) => selected = type),
        key));
    await tester.ensureVisible(find.text('موظف Study Birds'));
    await tester.tap(find.text('موظف Study Birds'));
    await tester.pump();
    await tester.tap(find.text('متابعة'));
    await tester.pump();
    expect(selected, 'employee');
    expect(find.text('ولي أمر'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'account-types');
  });
  for (final role in ['parent', 'university', 'employee']) {
    testWidgets('$role dashboard opens its live scoped resource',
        (tester) async {
      await fonts();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      final api = StudyBirdsApi(client: MockClient((req) async {
        paths.add(req.url.path);
        final Object result = req.url.path.endsWith('/overview')
            ? {
                'name': 'أحمد',
                'role': role,
                'students': 1,
                'applications': 2,
                'unreadMessages': 1,
                'manager': role == 'employee'
              }
            : req.url.path.endsWith('/students')
                ? [
                    {
                      'name': 'سارة',
                      'email': 'student@example.test',
                      '_id': 'student'
                    }
                  ]
                : req.url.path.endsWith('/applications')
                    ? [
                        {
                          'program': {'title': 'هندسة الحاسوب'},
                          'student': {'name': 'سارة'},
                          'university': {'name': 'الجامعة'},
                          'status': 'submitted',
                          '_id': 'application'
                        }
                      ]
                    : [];
        return http.Response(jsonEncode(result), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      api.user = {'name': 'أحمد', 'role': role, '_id': role};
      addTearDown(api.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(app(
          ConnectedHome(
              api: api,
              config: const {'modules': []},
              refreshConfig: () async {}),
          key));
      await tester.pumpAndSettle();
      expect(find.text('مرحباً أحمد'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, '$role-home');
      await tester.tap(find
          .text(role == 'university'
              ? 'الطلبات'
              : role == 'parent'
                  ? 'أبنائي'
                  : 'طلابي')
          .last);
      await tester.pumpAndSettle();
      expect(
          paths,
          contains(
              '/api/mobile-workspace/${role == 'university' ? 'applications' : 'students'}'));
      expect(find.text(role == 'university' ? 'هندسة الحاسوب' : 'سارة'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('employee task changes status through the API', (tester) async {
    final writes = <Map<String, dynamic>>[];
    final api = StudyBirdsApi(client: MockClient((req) async {
      if (req.method == 'PATCH') writes.add(jsonDecode(req.body));
      return http.Response(
          jsonEncode(req.method == 'GET'
              ? [
                  {'_id': 'task1', 'title': 'مراجعة الملف', 'status': 'pending'}
                ]
              : {'status': 'completed'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    api.user = {'role': 'employee'};
    addTearDown(api.dispose);
    await tester.pumpWidget(app(
        WorkspacePage(api: api, title: 'مهامي', route: 'tasks'), GlobalKey()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة الملف'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مكتملة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(writes.single['status'], 'completed');
    expect(tester.takeException(), isNull);
  });
  testWidgets('calendar and security use persisted dates and real sessions',
      (tester) async {
    await fonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final api = StudyBirdsApi(client: MockClient((req) async {
      final Object result = req.url.path.endsWith('/calendar')
          ? [
              {
                'title': 'موعد الاستشارة',
                'date': DateTime(now.year, now.month, 18).toIso8601String(),
                'description': 'لقاء المستشار'
              }
            ]
          : req.url.path.endsWith('/sessions')
              ? [
                  {
                    '_id': 'session',
                    'current': true,
                    'device': 'Test',
                    'lastSeen': now.toIso8601String()
                  }
                ]
              : req.url.path.endsWith('/profile')
                  ? {
                      'name': 'أحمد',
                      'email': 'student@example.test',
                      'emailVerified': false
                    }
                  : {};
      return http.Response(jsonEncode(result), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    api.user = {'role': 'student'};
    addTearDown(api.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(app(
        StudentFeaturePage(api: api, feature: 'calendar', title: 'المواعيد'),
        key));
    await tester.pumpAndSettle();
    expect(find.text('موعد الاستشارة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'calendar');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(
        StudentFeaturePage(api: api, feature: 'settings', title: 'الأمان'),
        key));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد البريد الإلكتروني'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'security');
    await tester.scrollUntilVisible(find.text('هذا الجهاز'), 250);
    expect(find.text('هذا الجهاز'), findsOneWidget);
  });
}
