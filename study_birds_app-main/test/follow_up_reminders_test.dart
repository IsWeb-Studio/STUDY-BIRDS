import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/follow_up_reminders_screen.dart';

void main() {
  testWidgets(
      'staff reminders acknowledge only the selected reminder and refresh',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    addTearDown(() => AuthSession.instance.token = null);
    var read = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: FollowUpRemindersScreen()));
      await tester.pumpAndSettle();
      expect(find.text('متابعة طلب متأخرة'), findsOneWidget);
      await tester.tap(find.text('تمت القراءة'));
      await tester.pumpAndSettle();
      expect(read, isTrue);
      expect(find.text('تمت القراءة'), findsNothing);
    },
        () => MockClient((request) async {
              expect(request.headers['authorization'], 'Bearer test-session');
              if (request.method == 'PATCH') {
                expect(request.url.path,
                    '/api/applications/follow-up-reminders/n1/read');
                read = true;
                return http.Response('{}', 200);
              }
              expect(request.url.path, '/api/applications/follow-up-reminders');
              return http.Response(
                  jsonEncode([
                    {
                      '_id': 'n1',
                      'title': 'متابعة طلب متأخرة',
                      'message': 'راجع الطلب',
                      'reminderApplication': 'a1',
                      'isRead': read
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
