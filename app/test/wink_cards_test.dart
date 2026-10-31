import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/games/wink_playing_card.dart';

void main() {
  testWidgets('hiding a known role mounts only the common back image',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: WinkPlayingCard(revealed: true, number: 7))));
    expect(find.byKey(const ValueKey('assets/images/games/covey_card_7.png')),
        findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: WinkPlayingCard(revealed: false, number: 7))));
    expect(find.byKey(const ValueKey('assets/images/games/covey_card_7.png')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('assets/images/games/covey_card_back.png')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('complete numbered artwork 1 through 11 is bundled at 2:3 aspect',
      () async {
    for (var i = 1; i <= 11; i++) {
      final data =
          await rootBundle.load('assets/images/games/covey_card_$i.png');
      expect(data.getUint32(16) / data.getUint32(20), closeTo(2 / 3, .001));
    }
  });
  testWidgets(
      'numbered image cards, private winker face and common photo back render',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontPath = Platform.environment['WINK_PREVIEW_FONT'];
    if (fontPath != null) {
      final font = FontLoader('serif')
        ..addFont(Future.value(
            ByteData.sublistView(File(fontPath).readAsBytesSync())));
      await tester.runAsync(font.load);
    }
    final bodyFont = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await tester.runAsync(bodyFont.load);
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Tajawal'),
        home: Scaffold(
            backgroundColor: const Color(0xFFE4DBCF),
            body: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                    color: const Color(0xFFE4DBCF),
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Wrap(spacing: 20, runSpacing: 20, children: [
                          for (var i = 1; i <= 12; i++)
                            SizedBox(
                                width: 270,
                                child: WinkPlayingCard(
                                    revealed: i != 12,
                                    number: i == 12 ? null : i))
                        ])))))));
    await tester.pumpAndSettle();
    // Decode bundled card artwork before inspecting/capturing the widgets.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(find.byType(WinkPlayingCard), findsNWidgets(12));
    for (var i = 1; i <= 10; i++) {
      expect(find.byKey(ValueKey('assets/images/games/covey_card_$i.png')),
          findsOneWidget);
    }
    expect(find.text('11'), findsNothing,
        reason: 'Protocol card 11 is the winker, not a numbered face.');
    expect(
        find.byKey(const ValueKey('assets/images/games/covey_card_winker.png')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('assets/images/games/covey_card_back.png')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    final output = Platform.environment['WINK_PREVIEW_OUT'];
    if (output != null) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
