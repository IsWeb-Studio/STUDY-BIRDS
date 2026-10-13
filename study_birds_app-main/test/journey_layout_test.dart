import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/repositories/student_repository.dart';
import 'package:study_birds/screens/home_journey/journey_requirements_view.dart';
import 'package:study_birds/screens/home_journey/journey_timeline_widgets.dart';

void main() {
  testWidgets(
      'journey reference layout fits mobile and keeps the rail on the right',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          null);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: JourneyRequirementsView(onRefresh: () async {}, journeys: [
            {
              'title': 'تركيا — إسطنبول — العلاج الطبيعي',
              'stages': [
                for (var i = 0; i < kJourneyStageOrder.length; i++)
                  {
                    'titleAr': kJourneyStageOrder[i]['title'],
                    'status': i < 4
                        ? 'completed'
                        : i == 4
                            ? 'in-progress'
                            : 'not-started',
                    'descriptionAr': i == 4 ? 'الجامعة تراجع طلبك حاليًا' : '',
                  }
              ],
            }
          ]),
        )));
    await tester.pumpAndSettle();
    expect(find.text('29% مكتمل — 4 من 14 مرحلة'), findsOneWidget);
    expect(tester.getCenter(find.text('5')).dx,
        greaterThan(tester.getCenter(find.text('مراجعة الجامعة')).dx));
    expect(find.byType(JourneySummaryCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.environment['CAPTURE_JOURNEY'] == '1') {
      await tester.runAsync(() async {
        final boundary = capture.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('.build-tools/journey-redesign.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
