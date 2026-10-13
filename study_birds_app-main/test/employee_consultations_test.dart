import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/repositories/consultation_repository.dart';
import 'package:study_birds/screens/roles/employee_consultations_screen.dart';

http.Response reply(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

const advisor = {'_id': 'advisor1', 'name': 'Sara'};
const slot = {
  '_id': 'slot1',
  '__v': 0,
  'startsAt': '2099-05-01T12:00:00.000Z',
  'mode': 'online',
  'enabled': true,
  'reservation': null,
  'advisor': advisor,
};
const booking = {
  '_id': 'booking1',
  '__v': 2,
  'startsAt': '2099-05-02T09:00:00.000Z',
  'status': 'booked',
  'student': {'_id': 'stu1', 'name': 'Ahmed'},
  'advisor': advisor,
  'slot': {
    'mode': 'online',
    'meetingUrl': 'https://meet.example.com/xyz',
    'instructions': ''
  },
};

void main() {
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets(
      'employee sees own consultant slots and bookings without an advisor filter',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'advisor1',
        name: 'Sara',
        email: 'sara@test.test',
        role: UserRole.employee,
        permissions: {'consultations'});
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ahmed'), findsOneWidget);
      expect(find.textContaining('المستشار:'), findsNothing);
      expect(find.text('تدير هنا مواعيدك الخاصة فقط. الأوقات بتوقيت جهازك.'),
          findsOneWidget);
    },
        () => MockClient((r) async {
              expect(r.headers['authorization'], 'Bearer test-session');
              if (r.url.path.endsWith('/staff/advisors')) {
                return reply([advisor]);
              }
              if (r.url.path.endsWith('/staff/slots')) return reply([slot]);
              if (r.url.path.endsWith('/staff/bookings')) {
                return reply([booking]);
              }
              return reply({}, 404);
            }));
  });

  testWidgets('admin view labels which consultant owns each slot and booking',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'admin1',
        name: 'Admin',
        email: 'admin@test.test',
        role: UserRole.admin);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('المستشار: Sara'), findsNWidgets(2));
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('/staff/advisors')) {
                return reply([advisor]);
              }
              if (r.url.path.endsWith('/staff/slots')) return reply([slot]);
              if (r.url.path.endsWith('/staff/bookings')) {
                return reply([booking]);
              }
              return reply({}, 404);
            }));
  });

  testWidgets('disabling a slot requires confirmation before the API call',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'advisor1',
        name: 'Sara',
        email: 'sara@test.test',
        role: UserRole.employee,
        permissions: {'consultations'});
    bool disabled = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعطيل'));
      await tester.pumpAndSettle();
      expect(disabled, isFalse);
      await tester.tap(find.text('تعطيل').last);
      await tester.pumpAndSettle();
      expect(disabled, isTrue);
      expect(find.text('معطّل'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (r.method == 'PATCH') {
                expect(
                    r.url.path, endsWith('/consultations/staff/slots/slot1'));
                expect(jsonDecode(r.body), {'version': 0, 'enabled': false});
                disabled = true;
                return reply({...slot, 'enabled': false, '__v': 1});
              }
              if (r.url.path.endsWith('/staff/advisors')) {
                return reply([advisor]);
              }
              if (r.url.path.endsWith('/staff/slots')) {
                return reply([
                  {...slot, 'enabled': !disabled, '__v': disabled ? 1 : 0}
                ]);
              }
              if (r.url.path.endsWith('/staff/bookings')) return reply([]);
              return reply({}, 404);
            }));
  });

  testWidgets('cancelling a booking requires confirmation before the API call',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'advisor1',
        name: 'Sara',
        email: 'sara@test.test',
        role: UserRole.employee,
        permissions: {'consultations'});
    bool cancelled = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء الحجز'));
      await tester.pumpAndSettle();
      expect(cancelled, isFalse);
      await tester.tap(find.text('إلغاء الحجز').last);
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
    },
        () => MockClient((r) async {
              if (r.method == 'POST') {
                expect(r.url.path,
                    endsWith('/consultations/bookings/booking1/cancel'));
                expect(jsonDecode(r.body), {'version': 2});
                cancelled = true;
                return reply({});
              }
              if (r.url.path.endsWith('/staff/advisors')) {
                return reply([advisor]);
              }
              if (r.url.path.endsWith('/staff/slots')) return reply([]);
              if (r.url.path.endsWith('/staff/bookings')) {
                return reply([
                  if (!cancelled)
                    booking
                  else
                    {...booking, 'status': 'cancelled'}
                ]);
              }
              return reply({}, 404);
            }));
  });

  testWidgets('expired disabled slots cannot be reactivated', (tester) async {
    AuthSession.instance.token = 'test-session';
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: EmployeeConsultationsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('منتهٍ'), findsOneWidget);
      expect(find.text('تفعيل'), findsNothing);
      expect(find.text('تعطيل'), findsNothing);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              if (request.url.path.endsWith('/staff/slots')) {
                return reply([
                  {
                    ...slot,
                    'enabled': false,
                    'startsAt': '2020-01-01T12:00:00Z'
                  }
                ]);
              }
              return reply([]);
            }));
  });

  test('publishing a slot posts the consultant, UTC time and meeting link', () {
    AuthSession.instance.token = 'test-session';
    addTearDown(() => AuthSession.instance.token = null);
    return http.runWithClient(() async {
      await ConsultationRepository.instance.publishSlot(
        advisorId: 'advisor1',
        startsAt: DateTime.utc(2099, 5, 1, 12, 30),
        mode: 'online',
        meetingUrl: 'https://meet.example.com/xyz',
      );
    },
        () => MockClient((r) async {
              expect(r.method, 'POST');
              expect(r.url.path, endsWith('/consultations/staff/slots'));
              expect(jsonDecode(r.body), {
                'advisorId': 'advisor1',
                'startsAt': '2099-05-01T12:30:00.000Z',
                'mode': 'online',
                'meetingUrl': 'https://meet.example.com/xyz',
                'instructions': '',
              });
              return reply({}, 201);
            }));
  });
}
