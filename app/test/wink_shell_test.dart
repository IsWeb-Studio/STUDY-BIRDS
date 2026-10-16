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
import 'package:study_birds/app_shell.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/games/wink_screen.dart';
import 'package:study_birds/screens/games/wink_playing_card.dart';
import 'wink_game_test.dart' show fixture;

void main() {
  testWidgets(
      'game has its own bottom tab, loads lazily and hides cards when switching',
      (tester) async {
    final preview = Platform.environment['WINK_SHELL_PREVIEW'];
    final boundary = GlobalKey();
    if (preview != null) {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Tajawal')
        ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await tester.runAsync(() async {
        await font.load();
        await icons.load();
      });
    }
    AuthSession.instance.token = 'shell-game';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'p0',
        name: 'Player',
        email: 'player@example.test',
        role: UserRole.student);
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });
    var gameRequests = 0, creates = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          locale: Locale(preview == null ? 'en' : 'ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(fontFamily: preview == null ? null : 'Tajawal'),
          home:
              RepaintBoundary(key: boundary, child: const StudentAppShell())));
      await tester.pump(const Duration(seconds: 1));
      expect(gameRequests, 0,
          reason: 'The offstage tab must not start a game connection.');
      for (var i = 0; i <= kTabGame; i++) {
        expect(find.byKey(ValueKey('main-tab-$i')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('main-tab-5')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.widget<WinkScreen>(find.byType(WinkScreen)).isActive, true);
      expect(find.byKey(const ValueKey('main-tabs-ai-button')), findsNothing);
      final create = find.text(preview == null ? 'Create room' : 'إنشاء غرفة');
      await tester.scrollUntilVisible(create, 180,
          scrollable: find.byType(Scrollable).last);
      await Scrollable.ensureVisible(tester.element(create), alignment: 0.4);
      await tester.pump();
      await tester.tap(create);
      await tester.pump(const Duration(seconds: 1));
      expect(creates, 1);
      await tester.pump(const Duration(milliseconds: 100));
      final card = find.byType(WinkPlayingCard);
      await tester.ensureVisible(card);
      await tester.pump(const Duration(milliseconds: 300));
      final pointer = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.widget<WinkPlayingCard>(card).revealed, true);
      if (preview != null) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      switchToMainTab(kTabHome);
      await tester.pump();
      expect(
          tester
              .widget<WinkPlayingCard>(
                  find.byType(WinkPlayingCard, skipOffstage: false))
              .revealed,
          false);
      await pointer.up();
      switchToMainTab(kTabGame);
      await tester.pump(const Duration(seconds: 1));
      expect(
          tester.widget<WinkPlayingCard>(find.byType(WinkPlayingCard)).revealed,
          false);
      expect(creates, 1, reason: 'Returning to a tab preserves the room.');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
          tester
              .widget<WinkScreen>(find.byType(WinkScreen, skipOffstage: false))
              .isActive,
          false,
          reason:
              'System back returns to home without trapping the user or leaving the room.');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
        () => MockClient((request) async {
              dynamic data = {};
              if (request.url.path.contains('/games/wink')) {
                gameRequests++;
                if (request.url.path.endsWith('/current')) {
                  data = {'code': null};
                } else {
                  data = fixture(phase: 'playing');
                  if (request.method == 'POST' &&
                      request.url.path.endsWith('/wink')) {
                    creates++;
                  }
                }
              } else if (request.url.path.endsWith('/overview')) {
                data = {'journeys': []};
              } else if ([
                '/universities',
                '/programs',
                '/countries',
                '/scholarships',
                '/services',
                '/banners'
              ].any(request.url.path.endsWith)) {
                data = [];
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
