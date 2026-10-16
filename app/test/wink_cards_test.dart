import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/games/wink_playing_card.dart';

void main() {
  testWidgets('ten numbered cards, private eye and a common hidden back render',
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
    // Decode the bundled ornament before inspecting/capturing the actual widgets.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(find.byType(WinkPlayingCard), findsNWidgets(12));
    for (var i = 1; i <= 10; i++) {
      expect(find.text('$i'), findsOneWidget);
    }
    expect(find.text('11'), findsNothing,
        reason: 'The eleventh face is the eye, not another numeral.');
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
