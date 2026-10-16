import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/home_dashboard_screen.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/home_journey/journey_preview_card.dart';

void main() {
  testWidgets('single journey on home uses the photo card and opens its own application', (tester) async {
    AuthSession.instance.token = 'test';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeDashboardScreen()));
      await tester.pumpAndSettle();
      final card = find.byType(JourneyPreviewCard);
      expect(card, findsOneWidget);
      expect(find.text('رحلة 1 من 1'), findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(find.text('متابعة الرحلة'));
      await tester.pumpAndSettle();
      expect(tester.widget<JourneyTrackerScreen>(find.byType(JourneyTrackerScreen).first).applicationId, 'single');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((r) async => http.Response(jsonEncode(
      r.url.path.endsWith('/overview') ? {
        'recentApplications': [
          {'_id': 'single', 'status': 'submitted', 'program': {'title': 'الطب', 'university': {'name': 'جامعة أنقرة'}}},
        ], 'journeys': [{'applicationId': 'single', 'stages': []}],
      } : []), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });
  testWidgets('home keeps horizontal swiping between redesigned journey cards', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthSession.instance.token = 'test';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeDashboardScreen()));
      await tester.pumpAndSettle();
      final card = find.byType(JourneyPreviewCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('رحلة 1 من 2'), findsOneWidget);
      expect(find.text('مراجعة المستندات'), findsOneWidget);
      expect(find.text('1 من 2 مراحل'), findsOneWidget);
      await tester.drag(card, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('رحلة 2 من 2'), findsOneWidget);
      expect(find.text('طب الأسنان'), findsOneWidget);
      await tester.tap(find.text('متابعة الرحلة').last);
      await tester.pumpAndSettle();
      expect(tester.widget<JourneyTrackerScreen>(find.byType(JourneyTrackerScreen).first).applicationId, 'b');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((r) async => http.Response(jsonEncode(
      r.url.path.endsWith('/overview') ? {
        'recentApplications': [
          {'_id': 'a', 'status': 'submitted', 'program': {'title': 'الطب البشري', 'university': {'name': 'جامعة أنقرة'}}},
          {'_id': 'b', 'status': 'under-review', 'program': {'title': 'طب الأسنان', 'university': {'name': 'جامعة إسطنبول'}}},
        ], 'journeys': [
          {'applicationId': 'a', 'stages': [
            {'titleAr': 'إرسال الطلب', 'status': 'completed'},
            {'titleAr': 'مراجعة المستندات', 'status': 'waiting'},
            {'titleAr': 'غير مطلوبة', 'status': 'not-required'},
          ]},
          {'applicationId': 'b', 'stages': []},
        ],
      } : []), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('journey card fits narrow screens at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: MediaQueryData(size: const Size(320, 900), textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body:
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(
            height: 440 + (14 * scale - 14) * 20,
            child: JourneyPreviewCard(title: 'هندسة البرمجيات والذكاء الاصطناعي',
              university: 'جامعة إسطنبول للتكنولوجيا والعلوم التطبيقية',
              location: 'تركيا · إسطنبول', status: 'قيد المراجعة', number: 1, total: 3,
              countryCode: 'TR', currentStage: 'مراجعة الطلب',
              progress: .25, onTap: () => opened = true),
          )))),
      )));
      await tester.pumpAndSettle();
      expect(find.text('رحلة 1 من 3'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('متابعة الرحلة'));
      expect(opened, isTrue);
    });
  }
}
