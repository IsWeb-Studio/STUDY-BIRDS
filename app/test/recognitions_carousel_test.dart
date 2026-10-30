import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/screens/home_journey/recognitions_carousel.dart';

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
        '$language recognition cards keep their seal and fit large text on a narrow screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: const Scaffold(
            body: RecognitionsCarousel(recognitions: [
          {'_id': 'one', 'title': 'شهادة واعتماد من المؤسسة التعليمية الدولية'},
          {'_id': 'two', 'title': 'Another certificate'},
        ])),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.verified), findsWidgets);
      expect(find.byIcon(Icons.workspace_premium_outlined), findsWidgets);
      expect(tester.getSize(find.byType(RecognitionCard).first).height,
          greaterThan(200));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'recognition image keeps its aspect ratio and opens a zoomable preview',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: RecognitionsCarousel(recognitions: [
      {
        '_id': 'image',
        'title': 'Certificate',
        'image': 'https://example.test/certificate.png'
      },
    ]))));
    await tester.pump();
    final cardImage =
        tester.widget<AppNetworkImage>(find.byType(AppNetworkImage));
    expect(cardImage.fit, BoxFit.contain);
    await tester.tap(find.byKey(const ValueKey('recognition-image')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
