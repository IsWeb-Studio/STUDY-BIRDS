import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/utils/app_error.dart';
import 'package:study_birds/core/widgets/app_notice.dart';
import 'package:study_birds/core/widgets/feature_ui.dart';
import 'package:study_birds/core/widgets/security_fields.dart';

void main() {
  testWidgets(
      'error card fits a narrow screen and large text, retry is actionable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: ErrorState(
                    message: AppError.connection, onRetry: () => retries++)))));
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('إعادة المحاولة'));
    await tester.tap(find.text('إعادة المحاولة'));
    // "Try again" verifies connectivity first (bounded), then retries.
    await tester.pump(const Duration(seconds: 10));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline errors and floating notices hide raw exception details',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Builder(
                builder: (context) => Column(children: [
                      const InlineNotice('MongoServerError secret',
                          error: true),
                      TextButton(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(AppSnackBar(
                                  content: Text(const ApiException(
                                          500, '<html>502 secret</html>')
                                      .message))),
                          child: const Text('show')),
                    ])))));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    expect(find.text(AppError.unexpected), findsOneWidget);
    expect(find.text(AppError.unavailable), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.textContaining('502'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility and Arabic code input preserve user values',
      (tester) async {
    final password = TextEditingController(text: 'MyPassword9!');
    final code = TextEditingController();
    addTearDown(password.dispose);
    addTearDown(code.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Column(children: [
          SecureTextField(controller: password),
          VerificationCodeField(controller: code),
        ]))));
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        true);
    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        false);
    expect(password.text, 'MyPassword9!');
    await tester.tap(find.byTooltip('إخفاء كلمة المرور'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        true);
    await tester.enterText(find.byType(TextField).last, '١٢٣٤٥٦');
    expect(code.text, '123456');
    expect(tester.takeException(), isNull);
  });
}
