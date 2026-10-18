import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/auth/verify_contact_screen.dart';

void main() {
  const user = AuthUser(
      id: 'u1',
      name: 'Student',
      email: 'student@example.test',
      role: UserRole.student,
      hasPassword: true,
      authProvider: 'google');
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });
  test(
      'real unverified email needs verification; verified providers and phone-only placeholders do not',
      () {
    expect(user.needsEmailVerification, true);
    expect(
        AuthUser.fromJson({...user.toJson(), 'emailVerified': true})
            .needsEmailVerification,
        false);
    expect(
        AuthUser.fromJson({
          ...user.toJson(),
          'authProvider': 'phone',
          'email': '201000000000@phone.studybirds.net'
        }).needsEmailVerification,
        false);
    expect(
        AuthUser.fromJson({...user.toJson(), 'authProvider': 'phone'})
            .needsEmailVerification,
        true);
  });
  testWidgets(
      'mandatory verification auto-sends and never trusts an empty success response',
      (tester) async {
    AuthSession.instance.token = 'onboarding-token';
    AuthSession.instance.currentUser = user;
    var requests = 0, confirmations = 0;
    var completed = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: VerifyContactScreen(
        mandatory: true,
        autoSend: true,
        contact: user.email,
        onVerify: () => completed = true,
      )));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
      expect(AuthSession.instance.currentUser!.emailVerified, false);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.text('تأكيد البريد'));
      await tester.tap(find.text('تأكيد البريد'));
      await tester.pumpAndSettle();
      expect(completed, false);
      expect(AuthSession.instance.currentUser!.emailVerified, false);
      await tester.ensureVisible(find.text('تأكيد البريد'));
      await tester.tap(find.text('تأكيد البريد'));
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(AuthSession.instance.currentUser!.emailVerified, true);
      expect(find.text('تم تأكيد بريدك'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/email/request')) {
                requests++;
                return http.Response('{}', 200);
              }
              if (request.url.path.endsWith('/email/confirm')) {
                confirmations++;
                expect(jsonDecode(request.body), {'code': '123456'});
                return http.Response(
                    confirmations == 1 ? '{}' : '{"emailVerified":true}', 200);
              }
              return http.Response(
                  jsonEncode({
                    'user': {...user.toJson(), 'emailVerified': true}
                  }),
                  200);
            }));
  });
}
