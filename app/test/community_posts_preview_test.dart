import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';

void main() {
  if (!const bool.fromEnvironment('COMMUNITY_POST_PREVIEW')) return;
  testWidgets('community post preview', (tester) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final emojiFont = File('C:/Windows/Fonts/seguiemj.ttf');
    if (emojiFont.existsSync()) {
      await (FontLoader('Segoe UI Emoji')
            ..addFont(Future.value(
                ByteData.sublistView(emojiFont.readAsBytesSync()))))
          .load();
    }
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'preview-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'me',
        name: 'Student',
        email: 'preview@example.test',
        role: UserRole.student);
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
      ApiClient.instance.clearCache();
    });
    final boundary = GlobalKey();
    await http.runWithClient(() async {
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const StudentCommunityScreen(embedded: true))));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('منشور الإدارة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('integration/previews/community-posts.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('/image')) {
                return http.Response.bytes(
                    File('assets/images/dashboard/campus.jpg')
                        .readAsBytesSync(),
                    200,
                    headers: {'content-type': 'image/jpeg'});
              }
              Object data = [];
              if (r.url.path.endsWith('/community/status')) {
                data = {'suspended': false};
              }
              if (r.url.path.endsWith('/community/posts')) {
                data = [
                  {
                    '_id': '111111111111111111111111',
                    'title': 'رحلتك تبدأ بخطوة',
                    'body':
                        'شاركنا خططك الدراسية، واسأل فريقنا عن خطوات التقديم والجامعات المتاحة.',
                    'author': {
                      '_id': 'admin',
                      'name': 'فريق COVEY',
                      'role': 'admin'
                    },
                    'isAdminPost': true,
                    'imagePath':
                        '/community/posts/111111111111111111111111/image',
                    'createdAt': '2026-10-29T10:00:00Z',
                    'reactionTotal': 18,
                    'reactionCounts': {'love': 10, 'like': 6, 'clap': 2},
                    'commentCount': 4
                  },
                  {
                    '_id': '222222222222222222222222',
                    'body':
                        'مين ناوي يدرس في تركيا السنة الجاية؟ خلّينا نتشارك التجارب والنصائح 🎓',
                    'author': {
                      '_id': 'student',
                      'name': 'سارة أحمد',
                      'role': 'student'
                    },
                    'reactionTotal': 3,
                    'reactionCounts': {'like': 3}
                  },
                ];
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
