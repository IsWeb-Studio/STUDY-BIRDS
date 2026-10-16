import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/main.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/auth/login_register_screens.dart';
import 'package:study_birds/screens/auth/onboarding_and_account_type_screens.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in UserRole.values) {
    testWidgets('logout from ${role.name} returns to account type even on older installs', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = AuthSession.instance;
      session.currentUser = AuthUser(id: 'user', name: 'Test', email: 'test@example.test', role: role);
      session.token = 'test';
      session.restoreNeedsNetwork = true;
      await session.logout(revoke: false);
      await tester.pumpWidget(const MaterialApp(home: RootChooserScreen()));
      await tester.pumpAndSettle();
      expect(session.currentUser, isNull);
      expect(session.token, isNull);
      expect(find.byType(AccountTypeSelectionScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('choosing a role opens login and back allows changing role', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AccountTypeEntry()));
    await tester.tap(find.text('جامعة'));
    await tester.pump();
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(LoginScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AccountTypeSelectionScreen), findsOneWidget);
    expect(AuthSession.instance.currentUser, isNull);
    expect(tester.takeException(), isNull);
  });
}
