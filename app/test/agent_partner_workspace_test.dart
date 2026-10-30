import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/agent_partner_workspace_screen.dart';

void main() {
  testWidgets('failed notification update gives feedback without a crash',
      (tester) async {
    AuthSession.instance.token = 'notification-test';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: AgentPartnerWorkspaceScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Notifications'));
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unread update'));
      await tester.pumpAndSettle();
      expect(find.text('Could not update the notification. Try again.'),
          findsOneWidget);
      expect(find.text('Unread update'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => http.Response(
              jsonEncode(request.method == 'GET'
                  ? [
                      {
                        '_id': 'notice',
                        'title': 'Unread update',
                        'isRead': false
                      }
                    ]
                  : {'message': 'Unavailable'}),
              request.method == 'GET' ? 200 : 503,
              headers: {'content-type': 'application/json'},
            )));
  });
  testWidgets('partner workspace loads referral data from the partner API',
      (tester) async {
    AuthSession.instance.token = 'partner-workspace-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'partner-1',
      name: 'Partner',
      email: 'partner@example.test',
      role: UserRole.agent,
    );
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: AgentPartnerWorkspaceScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Referral link'));
      await tester.pumpAndSettle();

      expect(find.text('https://birds.example.test/register?ref=PARTNER1'),
          findsOneWidget);
      expect(find.text('Code: PARTNER1'), findsOneWidget);
      expect(find.text('Registrations'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/partners/referral')) {
                return http.Response(
                    jsonEncode({
                      'referralCode': 'PARTNER1',
                      'referralLink':
                          'https://birds.example.test/register?ref=PARTNER1',
                      'summary': {
                        'clicks': 4,
                        'signups': 2,
                        'acceptedStudents': 1,
                        'generatedCommissions': 120,
                      },
                    }),
                    200,
                    headers: {'content-type': 'application/json'});
              }
              return http.Response('{}', 404,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
