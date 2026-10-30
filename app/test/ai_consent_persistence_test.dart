import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/ai_consent.dart';

AuthUser account(String id) => AuthUser(
    id: id, name: id, email: '$id@example.test', role: UserRole.student);

Widget consentPage(ValueChanged<bool> completed) => MaterialApp(
    key: UniqueKey(),
    home: Builder(
        builder: (context) => Scaffold(
                body: TextButton(
              onPressed: () async => completed(await requestAiConsent(context)),
              child: const Text('Open assistant'),
            ))));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.currentUser = account('one');
    AuthSession.instance.token = 'one-token';
  });
  tearDown(() {
    AuthSession.instance.currentUser = null;
    AuthSession.instance.token = null;
  });

  testWidgets('acceptance survives closing and recreating the assistant screen',
      (tester) async {
    bool? accepted;
    await tester.pumpWidget(consentPage((value) => accepted = value));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(accepted, true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ai_consent_v$aiConsentVersion:one'), true);
    accepted = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(consentPage((value) => accepted = value));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(accepted, true);
  });

  testWidgets(
      'saved consent is reused after signing into the same account but not another account',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'ai_consent_v$aiConsentVersion:one': true});
    AuthSession.instance.token = 'one-new-session';
    bool? accepted;
    await tester.pumpWidget(consentPage((value) => accepted = value));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    expect(accepted, true);
    AuthSession.instance.currentUser = account('two');
    AuthSession.instance.token = 'two-token';
    accepted = null;
    await tester.pumpWidget(consentPage((value) => accepted = value));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(accepted, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accepted, false);
  });

  testWidgets('cancelling does not save consent or suppress the next prompt',
      (tester) async {
    bool? accepted;
    await tester.pumpWidget(consentPage((value) => accepted = value));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accepted, false);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('ai_consent_v$aiConsentVersion:one'),
        isNull);
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('a prior terms version requires fresh acceptance',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ai_consent_v0:one': true});
    await tester.pumpWidget(consentPage((_) {}));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'switching accounts while the prompt is open cannot grant consent to either account',
      (tester) async {
    bool? accepted;
    await tester.pumpWidget(consentPage((value) => accepted = value));
    await tester.tap(find.text('Open assistant'));
    await tester.pumpAndSettle();
    AuthSession.instance.currentUser = account('two');
    AuthSession.instance.token = 'two-token';
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(accepted, false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ai_consent_v$aiConsentVersion:one'), isNull);
    expect(prefs.getBool('ai_consent_v$aiConsentVersion:two'), isNull);
  });
}
