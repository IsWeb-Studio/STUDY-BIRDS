import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/home_journey/journey_requirements_view.dart';
import 'package:study_birds/screens/home_journey/journey_preview_card.dart';
import 'package:study_birds/screens/home_journey/journey_selection_card.dart';

void main() {
  testWidgets('selection card fits narrow RTL screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: EdgeInsets.all(16),
            child: JourneySelectionCard(
              title: 'برنامج الهندسة وتكنولوجيا المعلومات',
              university: 'جامعة إسطنبول للدراسات والعلوم التطبيقية',
              location: 'تركيا · إسطنبول',
              status: 'بانتظار استكمال المستندات',
              currentStage: 'مراجعة المستندات الأكاديمية',
              number: 12,
              completedStages: 0,
              totalStages: 0,
              onTap: _noop,
            ),
          )))),
    )));
    expect(find.text('بانتظار تحديد المراحل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  final journeys = [
    {
      'applicationId': 'a',
      'title': 'الطب',
      'applicationStatus': 'submitted',
      'stages': [
        {'titleAr': 'إرسال الطلب', 'status': 'completed'},
        {'titleAr': 'مراجعة المستندات', 'status': 'waiting'},
        {'titleAr': 'غير مطلوبة', 'status': 'not-required'},
      ]
    },
    {
      'applicationId': 'b',
      'title': 'الهندسة',
      'applicationStatus': 'under-review',
      'stages': [
        {'titleAr': 'مراجعة الطلب', 'status': 'waiting'},
      ]
    },
  ];

  testWidgets(
      'multiple journeys use a distinct selection card with independent progress and navigation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: JourneyRequirementsView(
      journeys: journeys,
      onRefresh: () async {},
      applications: const [
        {
          '_id': 'a',
          'program': {
            'university': {'name': 'جامعة أنقرة'}
          }
        }
      ],
      detailBuilder: (journey) =>
          Scaffold(body: Text('Opened ${journey['applicationId']}')),
    )));
    expect(find.byType(JourneyPreviewCard), findsNothing);
    final firstCard = tester
        .widget<JourneySelectionCard>(find.byType(JourneySelectionCard).first);
    expect(firstCard.university, 'جامعة أنقرة');
    expect(firstCard.currentStage, 'مراجعة المستندات');
    expect(firstCard.progress, .5);
    expect(firstCard.totalStages, 2);
    final second = find.byType(JourneySelectionCard).last;
    await tester.ensureVisible(second);
    await tester.pumpAndSettle();
    final secondCard = tester.widget<JourneySelectionCard>(second);
    expect(secondCard.status, 'قيد المراجعة');
    expect(secondCard.progress, 0);
    await tester.tap(find.descendant(
        of: second, matching: find.byIcon(Icons.arrow_forward_rounded)));
    await tester.pumpAndSettle();
    expect(find.text('Opened b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one journey retains its existing steps view', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: JourneyRequirementsView(
      journeys: [journeys.first],
      onRefresh: () async {},
    )));
    expect(find.byType(JourneyPreviewCard), findsNothing);
    expect(find.text('مراجعة المستندات'), findsOneWidget);
    expect(find.text('طلبك قيد الانتظار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
