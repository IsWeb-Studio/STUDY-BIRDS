import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/utils/password_policy.dart';
import 'package:study_birds/core/widgets/security_fields.dart';

void main() {
  test('password policy agrees with server examples', () {
    for (final password in [
      '',
      'short1!',
      'abcdefgh',
      'Password123!',
      'Qwerty123!',
      'AaAaAaAa',
      'longlowercase123',
      'كلمةالمرور١٢٣',
      '${'é' * 40}Az9!'
    ]) {
      expect(PasswordPolicy.validate(password), isNotNull, reason: password);
    }
    for (final password in [
      'BirdFlight9',
      'Birds@Sky2',
      'رحلتي_التعليمية١٢٣',
      'Café_Route9',
      'Z9! a long phrase'
    ]) {
      expect(PasswordPolicy.validate(password), isNull, reason: password);
    }
  });
  testWidgets(
      'inline strength updates while typing and weak passwords cannot submit',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Form(
                key: form,
                child: SecureTextField(
                    controller: controller, requireStrong: true)))));
    expect(find.text('ابدأ الكتابة'), findsNothing);
    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();
    expect(find.text('ضعيفة'), findsOneWidget);
    expect(form.currentState!.validate(), false);
    await tester.enterText(find.byType(TextField), 'Birds@Sky2');
    await tester.pump();
    expect(find.text('قوية'), findsOneWidget);
    expect(form.currentState!.validate(), true);
    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();
    expect(controller.text, 'Birds@Sky2');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'login guidance leaves legacy passwords usable and fits narrow large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: 'legacy');
    addTearDown(controller.dispose);
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Form(
                        key: form,
                        child: SecureTextField(
                            controller: controller,
                            showStrength: true,
                            validator: (v) =>
                                v!.isEmpty ? 'أدخل كلمة المرور' : null)))))));
    expect(form.currentState!.validate(), true);
    expect(tester.takeException(), isNull);
  });
}
