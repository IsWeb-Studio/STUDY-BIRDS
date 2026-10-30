import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';

void main() {
  testWidgets('assigned team refresh replaces old names and handles removal', (tester) async {
    AuthSession.instance.token = 'synthetic-team-refresh';
    addTearDown(() => AuthSession.instance.token = null);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var members = [{'name': 'First employee', '_id': 'first'}];
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyTeamScreen()));
      await tester.pumpAndSettle();
      expect(find.text('First employee'), findsOneWidget);
      members = [{'name': 'New employee', '_id': 'new'}];
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('New employee'), findsOneWidget);
      expect(find.text('First employee'), findsNothing);
      members = [];
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('New employee'), findsNothing);
      expect(find.textContaining('لم يتم تعيين موظفين'), findsOneWidget);
      expect(requests, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
      expect(requests, 3);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      expect(request.url.path, endsWith('/students/support-team'));
      requests++;
      return http.Response(jsonEncode(members), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });
}
