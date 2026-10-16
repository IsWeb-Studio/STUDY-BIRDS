import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/app_shell.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/services/auth_session.dart';

void main() {
  testWidgets('AI shortcut belongs only to main tabs and stays fixed', (tester) async {
    AuthSession.instance.token = 'test';
    AuthSession.instance.currentUser = const AuthUser(id: 'u', name: 'Student', email: 'test@example.test', role: UserRole.student);
    addTearDown(() { AuthSession.instance.token = null; AuthSession.instance.currentUser = null; });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentAppShell()));
      await tester.pump(const Duration(seconds: 1));
      final button = find.byKey(const ValueKey('main-tabs-ai-button'));
      for (var tab = 0; tab < 5; tab++) {
        switchToMainTab(tab);
        await tester.pump(const Duration(milliseconds: 300));
        expect(button, findsOneWidget);
      }
      final before = tester.getCenter(button);
      await tester.drag(button, const Offset(-100, -100));
      await tester.pump();
      expect(tester.getCenter(button), before);
      final navigator = Navigator.of(tester.element(find.byType(StudentAppShell)));
      navigator.push(MaterialPageRoute<void>(builder: (_) => const AppScaffold(
          title: 'Inner page', body: Text('Details'))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(button, findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(button, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, () => MockClient((r) async {
      dynamic data = <String, dynamic>{};
      if (r.url.path.endsWith('/overview')) data = {'journeys': []};
      if (['/universities', '/programs', '/countries', '/scholarships', '/services', '/banners'].any(r.url.path.endsWith)) data = [];
      return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });

  testWidgets('ordinary scaffolds have no AI icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppScaffold(title: 'Login', body: Text('Form'))));
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
  });
}
