import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/current_user_avatar.dart';

void main() {
  testWidgets('menu and profile share photo updates and keep accounts separate', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final previous = AuthSession.instance.currentUser;
    addTearDown(() => AuthSession.instance.currentUser = previous);
    AuthSession.instance.currentUser = const AuthUser(id: 'avatar-a', name: 'Adam',
        email: 'a@example.test', role: UserRole.student);
    await tester.pumpWidget(const MaterialApp(home: Row(children: [
      CurrentUserAvatar(), CurrentUserAvatar(radius: 30),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNWidgets(2));
    final bytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==');
    await CurrentUserAvatar.save('avatar-a', bytes);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile_avatar_b64_avatar-a'), base64Encode(bytes));
    AuthSession.instance.currentUser = const AuthUser(id: 'avatar-b', name: 'Basma',
        email: 'b@example.test', role: UserRole.student);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: CurrentUserAvatar()));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
