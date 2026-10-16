import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/home_dashboard_screen.dart';
import 'package:study_birds/screens/home_journey/journey_requirements_view.dart';

void main() {
  testWidgets('post-admission home action opens the real journey and its evidence',
      (tester) async {
    AuthSession.instance.token = 'journey-test';
    addTearDown(() => AuthSession.instance.token = null);
    var reads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeDashboardScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('متابعة الرحلة'));
      await tester.tap(find.text('متابعة الرحلة'));
      await tester.pumpAndSettle();
      expect(find.byType(JourneyRequirementsView), findsOneWidget);
      expect(find.text('بانتظار فريق Study Birds'), findsOneWidget);
      expect(find.text('مرجع التحقق: VISA-1'), findsOneWidget);
      expect(find.text('مكتملة'), findsOneWidget);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      expect(request.url.path, '/api/students/overview');
      reads++;
      return http.Response(jsonEncode({
        'stats': {}, 'progress': {'stages': []},
        'nextAction': {
          'destination': 'journey', 'titleAr': 'متابعة السكن',
          'descriptionAr': 'بانتظار تأكيد السكن', 'waiting': true,
        },
        'journeys': [{
          'applicationId': 'a1', 'title': 'الطب', 'stages': [
            {'key': 'visa', 'titleAr': 'التأشيرة', 'status': 'completed', 'recordedStatus': 'completed', 'reference': 'VISA-1', 'descriptionAr': 'تحقق الفريق من التأشيرة'},
            {'key': 'housing', 'titleAr': 'السكن', 'status': 'waiting-team', 'recordedStatus': 'waiting-team', 'descriptionAr': 'بانتظار تأكيد السكن', 'destination': 'support'},
          ],
        }],
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });

  testWidgets('archived stage retains evidence and has no active support action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: JourneyRequirementsView(
      onRefresh: () async {},
      journeys: [{
        'title': 'طلب مؤرشف', 'closed': true, 'stages': [
          {'titleAr': 'التسجيل', 'status': 'waiting-university', 'recordedStatus': 'waiting-university', 'descriptionAr': 'آخر تحديث', 'destination': 'support', 'reference': 'REG-1'},
        ],
      }],
    )));
    expect(find.text('بانتظار الجامعة'), findsOneWidget);
    expect(find.text('مرجع التحقق: REG-1'), findsOneWidget);
    expect(find.text('تواصل بشأن التسجيل'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
