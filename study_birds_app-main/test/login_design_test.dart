import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/widgets/password_strength_card.dart';
import 'package:study_birds/core/widgets/password_strength_inline.dart';
import 'package:study_birds/screens/auth/login_register_screens.dart';

void main() {
  testWidgets(
      'login uses inline feedback and preserves visibility and submission',
      (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(
          onLoginAttempt: (email, password) async {
            submitted = '$email:$password';
            return true;
          },
        )));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordStrengthCard), findsNothing);
    expect(find.text('ابدأ الكتابة'), findsNothing);
    await tester.enterText(
        find.byType(TextField).first, ' student@example.com ');
    await tester.enterText(find.byType(TextField).last, 'Birds@Sky2');
    await tester.pumpAndSettle();
    expect(find.byType(PasswordStrengthInline), findsOneWidget);
    expect(find.text('قوية'), findsOneWidget);
    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        false);
    await tester.ensureVisible(find.text('تسجيل الدخول'));
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(submitted, 'student@example.com:Birds@Sky2');
    expect(tester.takeException(), isNull);
  });
  testWidgets('login remains readable on narrow screens and with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: LoginScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Birds@Sky2');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
