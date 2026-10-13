import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/employee_consultations_screen.dart';
import 'package:study_birds/screens/services_support/live_consultation_screen.dart';

http.Response reply(Object data, [int code = 200]) =>
    http.Response(jsonEncode(data), code,
        headers: {'content-type': 'application/json; charset=utf-8'});

const pastBooking = {
  '_id': 'past',
  '__v': 4,
  'status': 'booked',
  'startsAt': '2020-01-01T12:00:00Z',
  'student': {'name': 'Ahmed'},
  'advisor': {'name': 'Sara'},
  'slot': {'mode': 'office'},
};

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

  for (final conflict in [false, true]) {
    testWidgets(
        'outcome requires confirmation and preserves notes on conflict=$conflict',
        (tester) async {
      var saved = false;
      var writes = 0;
      const outcome = {
        'result': 'completed',
        'summary': 'Reviewed choices',
        'nextSteps': 'Upload transcript'
      };
      await http.runWithClient(() async {
        await tester
            .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تسجيل النتيجة'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextField).at(0), outcome['summary']!);
        await tester.enterText(
            find.byType(TextField).at(1), outcome['nextSteps']!);
        await tester.ensureVisible(find.text('حفظ النتيجة'));
        await tester.tap(find.text('حفظ النتيجة'));
        await tester.pumpAndSettle();
        expect(writes, 0);
        await tester.tap(find.text('حفظ ومشاركة'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        if (conflict) {
          expect(find.text('الحجز تغير؛ حدّث البيانات'), findsOneWidget);
          expect(find.widgetWithText(TextField, outcome['summary']!),
              findsOneWidget);
          expect(saved, isFalse);
        } else {
          expect(find.text('استشارة مكتملة'), findsOneWidget);
          expect(find.text('Upload transcript'), findsOneWidget);
          expect(find.text('تعديل النتيجة'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.method == 'PUT') {
                  writes++;
                  expect(request.url.path,
                      endsWith('/staff/bookings/past/outcome'));
                  expect(jsonDecode(request.body), {...outcome, 'version': 4});
                  if (conflict) {
                    return reply({'message': 'الحجز تغير؛ حدّث البيانات'}, 409);
                  }
                  saved = true;
                  return reply({});
                }
                if (request.url.path.endsWith('/staff/bookings')) {
                  return reply([
                    {
                      ...pastBooking,
                      if (saved) 'outcome': outcome,
                      if (saved) 'status': 'completed'
                    }
                  ]);
                }
                return reply([]);
              }));
    });
  }

  testWidgets('student sees shared outcome without booking actions',
      (tester) async {
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: LiveConsultationScreen()));
      await tester.pumpAndSettle();
      expect(find.text('استشارة مكتملة'), findsOneWidget);
      expect(find.text('Reviewed choices'), findsOneWidget);
      expect(find.text('Upload transcript'), findsOneWidget);
      expect(find.text('إلغاء الحجز'), findsNothing);
      expect(find.text('تغيير الموعد'), findsNothing);
      expect(find.text('تعديل النتيجة'), findsNothing);
    },
        () => MockClient(
            (request) async => reply(request.url.path.endsWith('/mine')
                ? [
                    {
                      ...pastBooking,
                      'status': 'completed',
                      'outcome': {
                        'result': 'completed',
                        'summary': 'Reviewed choices',
                        'nextSteps': 'Upload transcript'
                      }
                    }
                  ]
                : [])));
  });
}
