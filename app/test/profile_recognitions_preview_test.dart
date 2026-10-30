import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/screens/home_journey/recognitions_carousel.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';

void main() {
  testWidgets('render recognition artwork and profile grid', (tester) async {
    tester.view.physicalSize = const Size(900, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.runAsync(() => (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load());
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
                body: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListView(children: [
                      const SizedBox(height: 24),
                      const RecognitionsCarousel(recognitions: [
                        {'title': 'Techne Summit'},
                        {'title': 'BRITISH COUNCIL CERTIFIED'},
                        {'title': 'ISO 9001 CERTIFIED'},
                        {'title': 'ISO 10002 CERTIFIED'},
                      ]),
                      const SizedBox(height: 30),
                      GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          children: List.generate(
                              6,
                              (i) => CommunityProfilePostTile(post: {
                                    '_id': 'p$i',
                                    'title': 'Student post $i',
                                    'body': 'Study abroad'
                                  }, onTap: () {}))),
                    ]))))));
    for (final name in [
      'iso-9001.png',
      'iso-10002.png',
      'british-council.png',
      'techne-summit.png'
    ]) {
      await tester.runAsync(() => precacheImage(
          AssetImage('assets/images/branding/recognitions/$name'),
          tester.element(find.byType(RecognitionsCarousel))));
    }
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('integration/previews/covey-profile-recognitions.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('COVEY_BRAND_PREVIEW'));
}
