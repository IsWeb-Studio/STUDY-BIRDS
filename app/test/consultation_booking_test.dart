import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/student_events.dart';
import 'package:study_birds/screens/services_support/services_consultation_screens.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';

http.Response reply(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
const slot = {
  '_id': 'slot',
  'startsAt': '2099-05-01T12:00:00Z',
  'mode': 'online',
  'advisor': {'_id': 'advisor', 'name': 'Consultant'},
};
const booking = {
  '_id': 'booking',
  '__v': 3,
  'startsAt': '2099-05-01T11:00:00Z',
  'status': 'booked',
  'advisor': {'_id': 'advisor', 'name': 'Consultant'},
  'slot': {'mode': 'online'},
};
void main() {
  setUp(() => AuthSession.instance.token = 'test-session');
  tearDown(() => AuthSession.instance.token = null);

  testWidgets('date selection offers published days and keeps booking reachable',
      (tester) async {
    final start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2, hours: 12));
    final availableSlot = {...slot, 'startsAt': start.toUtc().toIso8601String()};
    var posted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ConsultationBookingScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('تصفية حسب التاريخ'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('تصفية حسب التاريخ'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(DateUtils.isSameDay(picker.initialDate, start), isTrue);
      expect(picker.selectableDayPredicate!(DateUtils.dateOnly(start)), isTrue);
      expect(picker.selectableDayPredicate!(DateUtils.dateOnly(start).add(const Duration(days: 1))), isFalse);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('حجز'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('حجز'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(posted, isTrue);
      expect(find.text('تم تأكيد موعدك بنجاح'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'slotId': 'slot'});
        posted = true;
        return reply({...booking, 'startsAt': availableSlot['startsAt']}, 201);
      }
      return reply(request.url.path.endsWith('/slots') ? [availableSlot] : []);
    }));
  });

  testWidgets('no published slots explains why no booking is offered', (tester) async {
    var requested = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ConsultationBookingScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('لا توجد مواعيد منشورة'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('حجز'), findsNothing);
      final dateButton = find.text('اختيار التاريخ المفضل');
      final press = tester.widget<TextButton>(find.ancestor(of: dateButton, matching: find.byType(TextButton))).onPressed!;
      press(); press(); press();
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('طلب تنسيق استشارة'));
      await tester.pumpAndSettle();
      expect(find.byType(NewSupportTicketScreen), findsOneWidget);
      expect(find.textContaining('أي نوع متاح'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('إرسال'), 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('إرسال'));
      await tester.pumpAndSettle();
      expect(requested, isTrue);
      expect(find.textContaining('تم إرسال طلبك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, endsWith('/students/support-tickets'));
        final body = jsonDecode(request.body) as Map;
        expect(body['category'], 'other');
        expect(body['message'], contains('أي نوع متاح'));
        expect(body['message'], contains('التاريخ المفضل'));
        requested = true;
        return reply({'_id': 'consultation-request'}, 201);
      }
      return reply([]);
    }));
  });

  testWidgets('consultation books an available slot only after confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool booked = false;
    int confirmed = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: ConsultationBookingScreen(onConfirm: () => confirmed++)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('حجز'));
      await tester.tap(find.text('حجز'));
      await tester.pumpAndSettle();
      expect(booked, false);
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(booked, true);
      expect(confirmed, 1);
      // After booking the app navigates to ConsultationConfirmationScreen.
      expect(find.text('تم تأكيد موعدك بنجاح'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              expect(r.headers['authorization'], 'Bearer test-session');
              if (r.method == 'POST') {
                expect(r.url.path, endsWith('/consultations/bookings'));
                expect(jsonDecode(r.body), {'slotId': 'slot'});
                booked = true;
                return reply(booking, 201);
              }
              return reply(r.url.path.endsWith('/slots')
                  ? (booked ? [] : [slot])
                  : (booked ? [booking] : []));
            }));
  });

  testWidgets(
      'failed reschedule retains original booking and does not confirm success',
      (tester) async {
    int confirmations = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: ConsultationBookingScreen(onConfirm: () => confirmations++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تغيير الموعد'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('اختيار'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('اختيار'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(confirmations, 0);
      await tester.scrollUntilVisible(find.text('الحجز مؤكد'), -250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('الحجز مؤكد'), findsOneWidget);
      expect(find.text('الموعد محجوز'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (r.method == 'POST') {
                expect(r.url.path, endsWith('/bookings/booking/reschedule'));
                expect(jsonDecode(r.body), {'version': 3, 'slotId': 'slot'});
                return reply({'message': 'الموعد محجوز'}, 409);
              }
              return reply(r.url.path.endsWith('/slots') ? [slot] : [booking]);
            }));
  });

  testWidgets(
      'cancelling requires confirmation and does not invoke booking callback',
      (tester) async {
    bool cancelled = false;
    int confirmations = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: ConsultationBookingScreen(onConfirm: () => confirmations++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء الحجز'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رجوع'));
      await tester.pumpAndSettle();
      expect(cancelled, false);
      await tester.tap(find.text('إلغاء الحجز'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(cancelled, true);
      expect(confirmations, 0);
      expect(find.text('ملغاة'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (r.method == 'POST') {
                expect(r.url.path, endsWith('/bookings/booking/cancel'));
                expect(jsonDecode(r.body), {'version': 3});
                cancelled = true;
                return reply({});
              }
              return reply(r.url.path.endsWith('/slots')
                  ? []
                  : [
                      {...booking, 'status': cancelled ? 'cancelled' : 'booked'}
                    ]);
            }));
  });

  testWidgets('unavailable consultations API does not claim a booking',
      (tester) async {
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: ConsultationBookingScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('خدمة المواعيد غير متاحة'), findsOneWidget);
      expect(find.text('حجز'), findsNothing);
    }, () => MockClient((r) async => reply({}, 404)));
  });

  test(
      'calendar includes confirmed consultations in local time and excludes cancellations',
      () {
    final events = calendarEvents(
        {},
        null,
        consultations: [
          booking,
          {...booking, 'status': 'cancelled'}
        ]);
    expect(events.length, 1);
    expect(events.single.title, 'موعد استشارة');
    expect(
        events.single.date, DateTime.parse('${booking['startsAt']}').toLocal());
  });
}
