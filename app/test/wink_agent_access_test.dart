import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/games/wink_screen.dart';

void main() {
  testWidgets('agent accounts cannot enter the game or initialize a room',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.currentUser = const AuthUser(
      id: 'agent-1',
      name: 'Agent',
      email: 'agent@example.test',
      role: UserRole.agent,
    );
    addTearDown(() => AuthSession.instance.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: WinkScreen()));
    await tester.pump();

    expect(find.text('The game is not available to agent accounts.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
