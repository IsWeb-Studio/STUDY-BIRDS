import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/home_journey/journey_requirements_view.dart';

void main() {
  testWidgets(
      'journey shows evidence states without an invented completion percentage',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: JourneyRequirementsView(onRefresh: () async {}, journeys: [
              {
                'title': 'الطب',
                'followUp': {
                  'advisor': {'name': 'أحمد'},
                  'dueAt': '2020-01-01T12:00:00Z',
                  'overdue': true
                },
                'stages': [
                  {
                    'titleAr': 'المستندات',
                    'status': 'waiting',
                    'descriptionAr': 'بانتظار اعتماد الفريق'
                  },
                  {
                    'titleAr': 'الدفع',
                    'status': 'overdue',
                    'descriptionAr': 'فاتورة متأخرة'
                  },
                ]
              },
            ]))));
    expect(find.text('بانتظار المراجعة'), findsOneWidget);
    expect(find.text('متأخرة'), findsOneWidget);
    // The only percentage allowed is the one derived from real stage counts
    // (0 of 2 stages complete => 0%), never an invented figure.
    expect(find.text('0% مكتمل — 0 من 2 مرحلة'), findsOneWidget);
    expect(find.textContaining('%'), findsNWidgets(2));
    expect(find.text('مسؤول المتابعة: أحمد'), findsOneWidget);
    expect(find.text('تأخرت متابعة الفريق عن الموعد المحدد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty journey does not claim an application exists',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: JourneyRequirementsView(journeys: [], onRefresh: () async {})));
    expect(find.text('لم تبدأ رحلة تقديم بعد'), findsOneWidget);
  });
}
