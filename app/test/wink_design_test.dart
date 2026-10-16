import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/screens/games/wink_screen.dart';
import 'package:study_birds/screens/games/wink_playing_card.dart';
import 'wink_game_test.dart' show fixture, DisplayGame;
import 'wink_game_test.dart' show mount;

void main() {
  testWidgets(
      'card stays open through role confirmation and hides on background',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await tester.runAsync(font.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    final boundary = GlobalKey();
    final game = DisplayGame(fixture());
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Tajawal'),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: RepaintBoundary(
            key: boundary, child: WinkScreen(controller: game))));
    await tester.pumpAndSettle();
    final card = find.byType(WinkPlayingCard);
    await tester.ensureVisible(card);
    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(tester.widget<WinkPlayingCard>(card).revealed, true);
    game.me['seen'] = true;
    game.room!['phase'] = 'playing';
    game.notifyListeners();
    await tester.pumpAndSettle();
    expect(tester.widget<WinkPlayingCard>(card).revealed, true);
    final output = Platform.environment['WINK_SCREEN_PREVIEW'];
    if (output != null) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    game.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.widget<WinkPlayingCard>(card).revealed, false);
    expect(tester.takeException(), isNull);
    final hubOutput = Platform.environment['WINK_HUB_PREVIEW'];
    if (hubOutput != null) {
      game.room = null;
      game.active = true;
      game.notifyListeners();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(hubOutput).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Sky roster scrolls to all eleven players without spectator actions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = fixture(phase: 'playing');
    data['players'] = [
      for (var i = 0; i < 11; i++)
        {
          'id': 'p$i',
          'name': 'Player $i',
          'connected': true,
          'eliminated': i == 10,
          'ready': true,
          'seen': true
        },
    ];
    await mount(tester, DisplayGame(data), language: 'en');
    final strip = find.byKey(const ValueKey('wink-player-strip'));
    await tester.scrollUntilVisible(strip, 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(strip), alignment: .2);
    await tester.pumpAndSettle();
    await tester.drag(strip, const Offset(-1800, 0));
    await tester.pumpAndSettle();
    final last = find.byKey(const ValueKey('wink-player-p10'));
    final lastBounds = tester.getRect(last);
    final viewport = tester.getRect(strip);
    expect(lastBounds.left, greaterThanOrEqualTo(viewport.left - .5));
    expect(lastBounds.right, lessThanOrEqualTo(viewport.right + .5));
    expect(find.descendant(of: last, matching: find.text('Spectating')),
        findsOneWidget);
    expect(find.descendant(of: last, matching: find.byType(TextButton)),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Sky sheets inherit the game theme inside a dark host application',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final game = DisplayGame(fixture(phase: 'lobby'));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(), home: WinkScreen(controller: game)));
    await tester.pumpAndSettle();
    final settings = find.text('Room settings');
    await tester.scrollUntilVisible(settings, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('Play at your own pace'), findsOneWidget);
    expect(
        Theme.of(tester.element(find.text('Play at your own pace'))).brightness,
        Brightness.light);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Play at your own pace'), findsNothing);
    await tester.tap(find.byTooltip('Sound and vibration'));
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.byType(SwitchListTile).first)).brightness,
        Brightness.light);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
