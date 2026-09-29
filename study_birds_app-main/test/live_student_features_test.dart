import 'package:study_birds/core/feature_ui.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/auth_session.dart';
import 'package:study_birds/core/student_events.dart';
import 'package:study_birds/core/student_repository.dart';
import 'package:study_birds/screens/profile_account/edit_profile_screen.dart';
import 'package:study_birds/screens/profile_account/security_settings_screen.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';
import 'package:study_birds/screens/home_journey/calendar_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/compare_list_screen.dart';
import 'package:study_birds/main.dart';
import 'package:study_birds/screens/auth/onboarding_and_account_type_screens.dart';

Widget app(Widget child) => MaterialApp(
    home: Directionality(textDirection: TextDirection.rtl, child: child));
http.Response response(Object? value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() {
    AuthSession.instance.token = 'test-session';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });

  test(
      'calendar uses actual unpaid invoice dates and arrival, ignoring invalid dates',
      () {
    final events = calendarEvents({
      'invoices': [
        {'dueDate': '2027-02-04', 'description': 'Tuition', 'status': 'unpaid'},
        {'dueDate': '2027-02-01', 'description': 'Paid', 'status': 'paid'},
        {'dueDate': 'invalid', 'status': 'unpaid'},
      ]
    }, {
      'arrivalDate': '2027-02-02',
      'airport': 'IST',
      'arrivalTime': '14:00'
    });
    expect(events.length, 2);
    expect(events.first.date.day, 2);
    expect(events.first.detail, 'IST 14:00');
    expect(events.last.title, contains('Tuition'));
    expect(calendarEvents({}, null), isEmpty);
  });

  test('activity uses real timestamps and orders newest first', () {
    final events = activityEvents([
      {
        'createdAt': '2027-01-01',
        'timeline': [
          {'changedAt': '2027-01-03', 'note': 'Reviewed'}
        ]
      }
    ], [
      {'createdAt': '2027-01-02', 'type': 'passport'}
    ], [
      {'createdAt': 'invalid', 'title': 'Invalid'}
    ]);
    expect(events.length, 3);
    expect(events.first.detail, 'Reviewed');
    expect(events.last.date.day, 1);
  });

  test('temporary server failures do not invalidate an existing account',
      () async {
    await http.runWithClient(() async {
      await expectLater(AuthService.instance.fetchCurrentUser('existing-token'),
          throwsA(isA<Exception>()));
    },
        () => MockClient((request) async =>
            http.Response('{"message":"Unavailable"}', 503)));
    await http.runWithClient(() async {
      expect(
          await AuthService.instance.fetchCurrentUser('expired-token'), isNull);
    },
        () => MockClient(
            (request) async => http.Response('{"message":"Expired"}', 401)));
  });

  testWidgets(
      'production entry starts onboarding without prototype or gallery chooser',
      (tester) async {
    AuthSession.instance.currentUser = null;
    await tester.pumpWidget(const StudyBirdsApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // Onboarding intentionally has a repeating animation.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(OnboardingIntroScreen), findsOneWidget);
    expect(find.byType(ScreensGallery), findsNothing);
    expect(find.textContaining('Prototype'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed profile save keeps the form and does not claim success',
      (tester) async {
    bool complete = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(app(EditProfileScreen(onSaved: () => complete = true)));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'الاسم بالإنجليزية'),
          'Keep my data');
      await tester.dragUntilVisible(find.text('حفظ البيانات'),
          find.byType(Scrollable).first, const Offset(0, -450));
      await tester.tap(find.text('حفظ البيانات'));
      await tester.pumpAndSettle();
      expect(complete, false);
      expect(find.textContaining('Save failed'), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
      await tester.dragUntilVisible(
          find.widgetWithText(TextFormField, 'الاسم بالإنجليزية'),
          find.byType(Scrollable).first,
          const Offset(0, 450));
      expect(find.text('Keep my data'), findsOneWidget);
    },
        () => MockClient((request) async => request.method == 'PUT'
            ? http.Response('{"message":"Save failed"}', 500)
            : response({})));
  });

  test('profile saves editable fields only and retains nested education data',
      () async {
    Map<String, dynamic>? saved;
    await http.runWithClient(
        () => StudentRepository.instance.updateProfile({
              'englishFullName': 'Tarek Test',
              'passportNumber': 'P123',
              'englishTest': {'exam': 'IELTS', 'score': '7'},
              'targetCountries': ['Turkey'],
              'journeyStage': 'studies-started',
              'user': 'other',
            }),
        () => MockClient((request) async {
              expect(request.method, 'PUT');
              expect(request.url.path, '/api/students/profile');
              expect(request.headers['authorization'], 'Bearer test-session');
              saved = jsonDecode(request.body);
              return response({});
            }));
    expect(saved!['englishTest'], {'exam': 'IELTS', 'score': '7'});
    expect(saved!['passportNumber'], 'P123');
    expect(saved!.containsKey('journeyStage'), false);
    expect(saved!.containsKey('user'), false);
  });

  testWidgets(
      'profile editor saves entered values and preserves fields not edited',
      (tester) async {
    Map<String, dynamic>? saved;
    bool complete = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(app(EditProfileScreen(onSaved: () => complete = true)));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'الاسم بالإنجليزية'),
          'Tarek Updated');
      await tester.dragUntilVisible(find.text('حفظ البيانات'),
          find.byType(Scrollable).first, const Offset(0, -450));
      await tester.tap(find.text('حفظ البيانات'));
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') {
                saved = jsonDecode(request.body);
                return response({});
              }
              return response({
                'englishFullName': 'Tarek Test',
                'passportNumber': 'P123',
                'targetCountries': ['Turkey'],
                'englishTest': {'exam': 'IELTS', 'score': '7'}
              });
            }));
    expect(complete, true);
    expect(saved?['englishFullName'], 'Tarek Updated');
    expect(saved?['passportNumber'], 'P123');
    expect(saved?['targetCountries'], ['Turkey']);
    expect(saved?['englishTest'], {'exam': 'IELTS', 'score': '7'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'password mismatch never sends request; valid change uses real endpoint',
      (tester) async {
    int calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const ChangePasswordScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.enterText(find.byType(TextFormField).at(2), 'mismatch');
      await tester.tap(find.text('حفظ كلمة المرور'));
      await tester.pump();
      expect(calls, 0);
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
      await tester.tap(find.text('حفظ كلمة المرور'));
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              calls++;
              expect(request.url.path, '/api/auth/change-password');
              expect(jsonDecode(request.body), {
                'currentPassword': 'old-password',
                'newPassword': 'new-password'
              });
              return response({});
            }));
    expect(calls, 1);
  });

  testWidgets('journey loads actual stage instead of demo position',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const JourneyTrackerScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 من 14'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => response({
              'profile': {'journeyStage': 'file-received'}
            })));
  });

  testWidgets('calendar changes months and contains no invented appointments',
      (tester) async {
    final now = DateTime.now();
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const CalendarScreen()));
      await tester.pumpAndSettle();
      expect(find.text('${arabicMonths[now.month - 1]} ${now.year}'),
          findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('لا توجد مواعيد لهذا اليوم'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('لا توجد مواعيد لهذا اليوم'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('الشهر التالي'));
      await tester.pump();
      final next = DateTime(now.year, now.month + 1);
      expect(find.text('${arabicMonths[next.month - 1]} ${next.year}'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient(
            (request) async => response(request.url.path.endsWith('financials')
                ? {'invoices': []}
                  : request.url.path.endsWith('/consultations/mine') || request.url.path.endsWith('/students/documents')
                    ? []
                    : null)));
  });

  testWidgets('comparison uses catalog data and persists selection',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const CompareListScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('University A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('University B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مقارنة (2)'));
      await tester.pumpAndSettle();
      expect(find.text('قارن قبل أن تختار'), findsOneWidget);
      expect(find.text('تعديل الاختيار'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('compare_universities_guest'), ['a', 'b']);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => response([
              {
                '_id': 'a',
                'name': 'University A',
                'country': {'name': 'Turkey'},
                'tuitionRange': {'min': 1000, 'max': 2000}
              },
              {
                '_id': 'b',
                'name': 'University B',
                'country': {'name': 'Georgia'}
              },
            ])));
  });
}
