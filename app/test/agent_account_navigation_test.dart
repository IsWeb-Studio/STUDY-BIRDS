import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/profile_account/my_streak.dart';
import 'package:study_birds/screens/profile_account/role_account_tab.dart';
import 'package:study_birds/screens/roles/agent_dashboard_screen.dart';

void main() {
  testWidgets('agent has an account tab but no streak or game entry',
      (tester) async {
    AuthSession.instance.token = 'agent-account-navigation';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'agent-1',
      name: 'Agent Account',
      email: 'agent@example.test',
      role: UserRole.agent,
    );
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AgentDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final appBar = find.byType(AppBar);
      expect(find.descendant(of: appBar, matching: find.byType(BackButton)),
          findsNothing);
      expect(
          find.descendant(
              of: appBar, matching: find.byIcon(Icons.notifications_outlined)),
          findsOneWidget);
      expect(
          find.descendant(
              of: appBar, matching: find.byIcon(Icons.more_vert_rounded)),
          findsOneWidget);
      expect(
          find.descendant(
              of: appBar, matching: find.byIcon(Icons.forum_outlined)),
          findsNothing);

      expect(find.byKey(const ValueKey('agent-bottom-navigation')),
          findsOneWidget);
      await tester.tap(find.text('حسابي').last);
      await tester.pump();

      expect(find.byType(RoleAccountTab), findsOneWidget);
      expect(find.text('Agent Account'), findsOneWidget);
      expect(find.byType(MyStreakCard), findsNothing);
      expect(
          find.byKey(const ValueKey('role-account-wink-game')), findsNothing);
      expect(find.text('لعبة الغمّازة'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
          find.text(
              '\u0645\u062c\u062a\u0645\u0639 \u0627\u0644\u0637\u0644\u0627\u0628'),
          findsNothing);
      expect(find.byKey(const ValueKey('student-community-hub')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              final payload = request.url.path.endsWith('/partners/overview')
                  ? <String, dynamic>{'stats': {}, 'notifications': []}
                  : <dynamic>[];
              return http.Response(jsonEncode(payload), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
