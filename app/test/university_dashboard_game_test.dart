import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/games/wink_screen.dart';
import 'package:study_birds/screens/profile_account/role_account_tab.dart';
import 'package:study_birds/screens/roles/university_dashboard_screen.dart';

void main() {
  testWidgets('university account is available from the bottom navigation',
      (tester) async {
    AuthSession.instance.token = 'university-account-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'university-account',
      name: 'Test University',
      email: 'university@example.test',
      role: UserRole.university,
    );
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: UniversityDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byKey(const ValueKey('university-bottom-navigation')),
          findsOneWidget);
      const communityLabel = '\u0645\u062c\u062a\u0645\u0639 \u0627\u0644\u0637\u0644\u0627\u0628';
      expect(find.text(communityLabel), findsOneWidget);
      await tester.tap(find.text(communityLabel));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('student-community-hub')), findsOneWidget);
      await tester.tap(find.text('حسابي').last);
      await tester.pump();
      expect(find.byType(RoleAccountTab), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('role-account-wink-game')),
        240,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('role-account-tab')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
          find.byKey(const ValueKey('role-account-wink-game')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              final Object body =
                  path.endsWith('/university-portal/applications')
                      ? <dynamic>[]
                      : path.endsWith('/university-portal/favorites-count')
                          ? {'count': 0}
                          : {'streak_days': 0, 'activityCalendar': []};
              return http.Response(jsonEncode(body), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets(
      'university dashboard opens the same Winker game and its local mode',
      (tester) async {
    AuthSession.instance.token = 'university-game-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'university-1',
      name: 'Test University',
      email: 'university@example.test',
      role: UserRole.university,
    );
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    var currentRoomRequests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        home: UniversityDashboardScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final entry = find.byKey(const ValueKey('university-wink-game'));
      expect(find.byKey(const ValueKey('university-my-streak-university-1')),
          findsOneWidget);
      expect(find.text('Start a new streak by playing online'), findsOneWidget);
      await tester.ensureVisible(entry);
      expect(entry, findsOneWidget);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WinkScreen), findsOneWidget);
      final localMode = find.textContaining('One device');
      await tester.ensureVisible(localMode);
      expect(localMode, findsOneWidget);
      expect(currentRoomRequests, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1100));
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path.endsWith('/university-portal/applications')) {
                return http.Response('[]', 200,
                    headers: {'content-type': 'application/json'});
              }
              if (path.endsWith('/university-portal/favorites-count')) {
                return http.Response(jsonEncode({'count': 0}), 200,
                    headers: {'content-type': 'application/json'});
              }
              if (path.endsWith('/games/wink/current')) {
                currentRoomRequests++;
                return http.Response(jsonEncode({'code': null}), 200,
                    headers: {'content-type': 'application/json'});
              }
              if (path.endsWith('/stories/progress')) {
                return http.Response(
                    jsonEncode({'streak_days': 0, 'activityCalendar': []}), 200,
                    headers: {'content-type': 'application/json'});
              }
              return http.Response('{}', 404,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
