import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/screens/roles/employee_dashboard_screen.dart';
import 'package:study_birds/screens/roles/parent_dashboard_screen.dart';
import 'package:study_birds/screens/roles/university_dashboard_screen.dart';

http.Response jsonReply(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});

void main() {
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets('parent account exposes online game and game-based streak',
      (tester) async {
    AuthSession.instance.token = 'parent-activity-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'parent-1',
      name: 'Parent',
      email: 'parent@example.test',
      role: UserRole.parent,
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ParentDashboardScreen()));
      await tester.pumpAndSettle();
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
      final account = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.person_outline_rounded),
      );
      const communityLabel =
          '\u0645\u062c\u062a\u0645\u0639 \u0627\u0644\u0637\u0644\u0627\u0628';
      expect(find.text(communityLabel), findsOneWidget);
      await tester.tap(find.text(communityLabel));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.byKey(const ValueKey('student-community-hub')), findsOneWidget);
      expect(
          tester
              .widget<BottomNavigationBar>(
                  find.byKey(const ValueKey('parent-bottom-navigation')))
              .selectedItemColor,
          AppColors.greenInk);
      await tester.tap(account);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 30));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('parent-wink-game')),
        240,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('role-account-tab')),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.byKey(const ValueKey('parent-my-streak-parent-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('parent-wink-game')), findsOneWidget);
      expect(find.text('Start a new streak by playing online'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/parents/children') ||
                  request.url.path.endsWith('/parents/link-requests')) {
                return jsonReply([]);
              }
              if (request.url.path.endsWith('/stories/progress')) {
                return jsonReply({'streak_days': 0, 'activityCalendar': []});
              }
              return jsonReply({});
            }));
  });

  testWidgets('employee dashboard exposes the game and online streak',
      (tester) async {
    AuthSession.instance.token = 'employee-activity-test';
    const user = AuthUser(
      id: 'employee-1',
      name: 'Employee',
      email: 'employee@example.test',
      role: UserRole.employee,
    );
    AuthSession.instance.currentUser = user;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: EmployeeDashboardScreen(user: user),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.byKey(const ValueKey('employee-my-streak-employee-1')),
          findsOneWidget);
      expect(find.text('Start a new streak by playing online'), findsNothing);
      final appBar = find.byType(AppBar);
      expect(find.descendant(of: appBar, matching: find.byType(BackButton)),
          findsNothing);
      expect(
          find.descendant(
              of: appBar, matching: find.byIcon(Icons.sports_esports_outlined)),
          findsNothing);
      final account = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.person_outline_rounded),
      );
      await tester.tap(account);
      await tester.pump();
      expect(find.byKey(const ValueKey('role-account-tab')), findsOneWidget);
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
              if (request.url.path.endsWith('/stories/progress')) {
                return jsonReply({'streak_days': 0, 'activityCalendar': []});
              }
              return jsonReply({});
            }));
  });

  testWidgets('university dashboard shares Community and own game streak',
      (tester) async {
    AuthSession.instance.token = 'university-activity-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'university-1',
      name: 'University',
      email: 'university@example.test',
      role: UserRole.university,
    );
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: UniversityDashboardScreen()));
      await tester.pumpAndSettle();
      final appBar = find.byType(AppBar);
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
      expect(find.byKey(const ValueKey('university-my-streak-university-1')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('university-wink-game')), findsOneWidget);
      await tester.tap(find.text('مجتمع الطلاب'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.byKey(const ValueKey('student-community-hub')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path
                  .endsWith('/university-portal/applications')) {
                return jsonReply([]);
              }
              if (request.url.path
                  .endsWith('/university-portal/favorites-count')) {
                return jsonReply({'count': 0});
              }
              if (request.url.path.endsWith('/stories/progress')) {
                return jsonReply({'streak_days': 0, 'activityCalendar': []});
              }
              return jsonReply({});
            }));
  });
}
