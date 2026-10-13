import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/auth/email_challenge_screen.dart';

void main() {
  testWidgets('challenge rejects invalid input and preserves route on server failure', (tester) async {
    var attempts = 0;
    bool? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () async { result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EmailChallengeScreen(confirm: (code) async {
        attempts++;
        expect(code, '123456');
        if (attempts == 1) throw Exception('rejected');
      }))); }, child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(EmailChallengeScreen), findsOneWidget);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
