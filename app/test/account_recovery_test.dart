import 'package:study_birds/screens/auth/verify_contact_screen.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/auth/account_recovery_screen.dart';

void main() {
  testWidgets('email verification requires a successful server confirmation',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    addTearDown(() => AuthSession.instance.token = null);
    bool confirmed = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: VerifyContactScreen(
              contact: 'student@example.test',
              onVerify: () => confirmed = true)));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      expect(confirmed, false);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('تأكيد البريد'));
      await tester.pumpAndSettle();
      expect(confirmed, true);
      expect(find.text('تم تأكيد بريدك'), findsOneWidget);
    },
        () => MockClient((r) async {
              expect(r.headers['authorization'], 'Bearer test-session');
              if (r.url.path.endsWith('/confirm')) {
                expect(jsonDecode(r.body), {'code': '123456'});
              }
              return http.Response(r.url.path.endsWith('/confirm') ? '{"emailVerified":true}' : '{}', 200);
            }));
  });
  testWidgets('unavailable email verification never claims code was sent',
      (tester) async {
    AuthSession.instance.token = 'test-session';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: VerifyContactScreen()));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('تأكيد البريد غير متاح'), findsOneWidget);
    }, () => MockClient((r) async => http.Response('{}', 404)));
  });

  testWidgets(
      'recovery requests code then confirms password without claiming success early',
      (tester) async {
    // The strength meter makes the form taller than the default 800x600 view.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AccountRecoveryScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).first, 'student@example.test');
      await tester.tap(find.text('إرسال رمز الاستعادة'));
      await tester.pumpAndSettle();
      expect(find.text('تحقق من بريدك'), findsOneWidget);
      expect(find.text('تم تحديث كلمة المرور'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'Birds@Sky2026');
      await tester.enterText(find.byType(TextFormField).at(2), 'Birds@Sky2026');
      await tester.ensureVisible(find.text('تعيين كلمة المرور'));
      await tester.tap(find.text('تعيين كلمة المرور'));
      await tester.pumpAndSettle();
      expect(find.text('تم تحديث كلمة المرور'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              paths.add(r.url.path);
              if (r.url.path.endsWith('/confirm')) {
                expect(jsonDecode(r.body), {
                  'email': 'student@example.test',
                  'code': '123456',
                  'password': 'Birds@Sky2026'
                });
              }
              return http.Response('{}', 200,
                  headers: {'content-type': 'application/json'});
            }));
    expect(paths, contains('/api/mobile-security/reset/request'));
    expect(paths, contains('/api/mobile-security/reset/confirm'));
  });
  testWidgets(
      'missing recovery service offers support and never advances to code form',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AccountRecoveryScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).first, 'student@example.test');
      await tester.tap(find.text('إرسال رمز الاستعادة'));
      await tester.pumpAndSettle();
      expect(find.text('تحقق من بريدك'), findsNothing);
      expect(find.textContaining('الاستعادة بالرمز غير متاحة'), findsOneWidget);
      expect(find.text('support@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => http.Response(
            r.method == 'POST'
                ? '{}'
                : '{"contactEmail":"support@example.test"}',
            r.method == 'POST' ? 404 : 200,
            headers: {'content-type': 'application/json'})));
  });
}
