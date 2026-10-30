import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/screens/profile_account/role_account_tab.dart';
import 'package:study_birds/screens/roles/employee_dashboard_screen.dart';

void main() {
  testWidgets('admin and employee dashboard navigation includes My Account',
      (tester) async {
    AuthSession.instance.token = 'employee-account-navigation';
    const user = AuthUser(
      id: 'admin-account',
      name: 'Admin Account',
      email: 'admin@example.test',
      role: UserRole.admin,
    );
    AuthSession.instance.currentUser = user;
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: EmployeeDashboardScreen(user: user),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

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
              of: appBar, matching: find.byIcon(Icons.sports_esports_outlined)),
          findsNothing);
      expect(
          find.descendant(
              of: appBar, matching: find.byIcon(Icons.forum_outlined)),
          findsNothing);
      expect(
          find.descendant(
              of: appBar,
              matching: find.byIcon(Icons.notifications_active_outlined)),
          findsNothing);

      expect(find.text('حسابي'), findsOneWidget);
      await tester.tap(find.text('حسابي'));
      await tester.pump();
      expect(find.byType(RoleAccountTab), findsOneWidget);
      expect(find.text('Admin Account'), findsOneWidget);
      expect(find.byKey(const ValueKey('role-account-streak-admin-account')),
          findsOneWidget);
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
      const communityLabel =
          '\u0645\u062c\u062a\u0645\u0639 \u0627\u0644\u0637\u0644\u0627\u0628';
      expect(find.text(communityLabel), findsOneWidget);
      await tester.tap(find.text(communityLabel));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.byKey(const ValueKey('student-community-hub')), findsOneWidget);
      final navigation = tester.widget<BottomNavigationBar>(
          find.byKey(const ValueKey('employee-bottom-navigation')));
      expect(navigation.selectedItemColor, AppColors.greenInk);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              final body = request.url.path.endsWith('/admin/my-kpis')
                  ? <String, dynamic>{}
                  : request.url.path.endsWith('/stories/progress')
                      ? <String, dynamic>{
                          'streak_days': 0,
                          'activityCalendar': <dynamic>[],
                        }
                      : <String, dynamic>{'stats': {}, 'notifications': []};
              return http.Response(jsonEncode(body), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
