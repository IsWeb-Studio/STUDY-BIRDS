import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/connected/connected_app.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/study_birds_api.dart';

const preview = bool.fromEnvironment('WRITE_UI_PREVIEWS');
void main() {
  testWidgets(
      'original five-tab home keeps live overview and module navigation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (preview) {
      final icons = File(
          'D:/fluter/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
      if (icons.existsSync()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
        await loader.load();
      }
      final font = File('C:/Windows/Fonts/tahoma.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('PreviewArabic')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await loader.load();
      }
    }
    final paths = <String>[];
    final api = StudyBirdsApi(client: MockClient((request) async {
      paths.add(request.url.path);
      final response = request.url.path.endsWith('/overview')
          ? {
              'stats': {'currentApplications': 2, 'acceptedDocuments': 3},
              'progress': {
                'currentStage': 'applying',
                'stages': [
                  {
                    'key': 'file-received',
                    'titleAr': 'استلام الملف',
                    'status': 'completed'
                  },
                  {
                    'key': 'applying',
                    'titleAr': 'التقديم للجامعة',
                    'status': 'current'
                  },
                  {
                    'key': 'final-accepted',
                    'titleAr': 'القبول النهائي',
                    'status': 'upcoming'
                  },
                ]
              },
            }
          : [];
      return http.Response(jsonEncode(response), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    api.user = {
      'name': 'أحمد',
      'email': 'student@example.test',
      'role': 'student'
    };
    addTearDown(api.dispose);
    final boundary = GlobalKey();
    const modules = {
      'overview': 'الرئيسية',
      'applications': 'طلباتي',
      'documents': 'مستنداتي',
      'universities': 'الجامعات',
      'programs': 'التخصصات',
      'countries': 'الدول',
      'scholarships': 'المنح الدراسية',
      'orientation-test': 'التوجيه الدراسي',
      'consultations': 'استشارة',
      'services': 'الخدمات',
      'visa': 'التأشيرة',
      'travel': 'السفر',
      'accommodation': 'السكن',
      'insurance': 'التأمين',
      'profile': 'الملف الشخصي',
      'notifications': 'الإشعارات',
    };
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              fontFamily: preview ? 'PreviewArabic' : null,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.navy, primary: AppColors.navy)),
          home: ConnectedHome(api: api, refreshConfig: () async {}, config: {
            'title': 'Study Birds',
            'welcome': 'خطواتك القادمة نحو حلمك',
            'banners': const [],
            'modules': [
              for (final entry in modules.entries)
                {
                  'key': entry.key,
                  'title': entry.value,
                  'enabled': true,
                  'order': modules.keys.toList().indexOf(entry.key)
                }
            ],
          }),
        )));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('رحلتك الحالية'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(paths, ['/api/students/overview']);
    expect(tester.takeException(), isNull);
    if (preview) await capture(tester, boundary, 'home');

    await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar), matching: find.text('الخدمات')));
    await tester.pumpAndSettle();
    expect(find.text('التأشيرة'), findsOneWidget);
    expect(find.text('السفر'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsNothing);
    expect(tester.takeException(), isNull);
    if (preview) await capture(tester, boundary, 'services');

    await tester.tap(find.text('استكشاف'));
    await tester.pumpAndSettle();
    if (preview) await capture(tester, boundary, 'explore');
    await tester.tap(find.text('التخصصات'));
    await tester.pumpAndSettle();
    expect(paths.last, '/api/programs');
    expect(find.text('لا توجد نتائج حالياً'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    expect(find.text('student@example.test'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (preview) await capture(tester, boundary, 'account');
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('integration/previews')
      ..createSync(recursive: true);
    File('${folder.path}/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}
