import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  setUp(() {
    AuthSession.instance.token = 'support-test';
    ApiClient.instance.clearCache();
  });
  tearDown(() => AuthSession.instance.token = null);
  for (final assigned in [false, true]) {
    testWidgets(
        'my team shows ${assigned ? 'assigned employees only' : 'an honest empty state'}',
        (tester) async {
      await http.runWithClient(() async {
        await mount(tester, const MyTeamScreen());
        expect(find.text('فريق الدعم'), findsNothing);
        expect(find.text('فريق القبول'), findsNothing);
        expect(find.text('مراسلة'), findsNothing);
        expect(find.text('Employee One'),
            assigned ? findsOneWidget : findsNothing);
        expect(find.textContaining('لم يتم تعيين موظفين'),
            assigned ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                expect(request.url.path, '/api/students/support-team');
                return http.Response(
                    jsonEncode(assigned
                        ? [
                            {'_id': 'one', 'name': 'Employee One'}
                          ]
                        : []),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
    });
  }
  testWidgets('submitting a problem opens my tickets', (tester) async {
    var created = false;
    await http.runWithClient(() async {
      await mount(tester, const SupportCenterScreen());
      await tester.tap(find.text('تذكرة دعم جديدة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'App problem');
      await tester.enterText(find.byType(TextField).at(1), 'Something is slow');
      await tester.ensureVisible(find.text('إرسال'));
      await tester.tap(find.text('إرسال'));
      await tester.pumpAndSettle();
      expect(created, true);
      expect(find.byType(SupportTicketsListScreen), findsOneWidget);
      expect(find.text('App problem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                created = true;
                expect(jsonDecode(request.body)['category'], 'technical-issue');
              }
              return http.Response(
                  jsonEncode(request.method == 'POST'
                      ? {'_id': 'ticket'}
                      : [
                          {
                            '_id': 'ticket',
                            'subject': 'App problem',
                            'status': 'open',
                            'category': 'technical-issue'
                          }
                        ]),
                  request.method == 'POST' ? 201 : 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
