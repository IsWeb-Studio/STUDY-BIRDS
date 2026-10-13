import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/employee_consultations_screen.dart';

void main() {
  setUp(() {
    AuthSession.instance.token = 'test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'staff',
        name: 'Sara',
        email: 'sara@example.test',
        role: UserRole.employee,
        permissions: {'consultations'});
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  for (final scenario in [(3, false), (3, true), (12, false)]) {
    final count = scenario.$1;
    final conflict = scenario.$2;
    testWidgets(
        'weekly slots are confirmed as one atomic request; count=$count conflict=$conflict',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day + 2);
      await http.runWithClient(() async {
        await tester
            .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('نشر موعد جديد'));
        await tester.pumpAndSettle();
        tester
            .widget<DropdownButtonFormField<int>>(
                find.byType(DropdownButtonFormField<int>))
            .onChanged!(count);
        await tester.pumpAndSettle();
        await tester.tap(find.text('اختر تاريخًا'));
        await tester.pumpAndSettle();
        tester
            .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
            .onDateChanged(day);
        await tester.pump();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        tester
            .widget<DropdownButton<TimeOfDay>>(
                find.byType(DropdownButton<TimeOfDay>))
            .onChanged!(const TimeOfDay(hour: 12, minute: 0));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextField).first, 'https://meet.example.test/consult');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('نشر الموعد'));
        await tester.tap(find.text('نشر الموعد'));
        await tester.pumpAndSettle();
        expect(writes, 0);
        expect(find.text('نشر مواعيد أسبوعية'), findsOneWidget);
        await tester.tap(find.text('نشر المواعيد'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        if (conflict) {
          expect(find.text('أحد المواعيد موجود؛ لم تُنشر المجموعة'),
              findsOneWidget);
          expect(
              find.widgetWithText(
                  TextField, 'https://meet.example.test/consult'),
              findsOneWidget);
        } else {
          expect(find.text('الاستشارات والمواعيد'), findsOneWidget);
          expect(find.text('نشر موعد استشارة'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                Object data = [];
                int status = 200;
                if (request.method == 'POST') {
                  writes++;
                  expect(request.url.path, endsWith('/staff/slots/batch'));
                  expect(jsonDecode(request.body), {
                    'advisorId': 'staff',
                    'startsAt': List.generate(
                    count,
                        (i) =>
                            DateTime(day.year, day.month, day.day + i * 7, 12)
                                .toUtc()
                                .toIso8601String()),
                    'mode': 'online',
                    'meetingUrl': 'https://meet.example.test/consult',
                    'instructions': '',
                  });
                  if (conflict) {
                    status = 409;
                    data = {'message': 'أحد المواعيد موجود؛ لم تُنشر المجموعة'};
                  }
                } else if (request.url.path.endsWith('/staff/advisors')) {
                  data = [
                    {'_id': 'staff', 'name': 'Sara'}
                  ];
                }
                return http.Response(jsonEncode(data), status, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
    });
  }
}
