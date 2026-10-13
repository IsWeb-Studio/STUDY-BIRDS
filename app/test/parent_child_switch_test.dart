import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/parent_dashboard_screen.dart';

http.Response reply(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> overview(String name, String intake) => {
      'student': {'name': name},
      'intake': intake,
      'targetCountries': [],
      'applications': [],
    };

void main() {
  setUp(() => AuthSession.instance.token = 'parent');
  tearDown(() => AuthSession.instance.token = null);

  // Audit 24 Sep, note 4: a slow answer for the previously selected child
  // must never replace the newly selected child's data.
  testWidgets('a late response for the previous child is ignored',
      (tester) async {
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: ParentDashboardScreen()));
      // Child A's overview is slow (see mock); switch to B before it lands.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Basel'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Fall 2027'), findsOneWidget);
      expect(find.text('Fall 2026'), findsNothing);
    },
        () => MockClient((r) async {
              final path = r.url.path;
              if (path.endsWith('/parents/children')) {
                return reply([
                  {'_id': 'a', 'name': 'Amal'},
                  {'_id': 'b', 'name': 'Basel'},
                ]);
              }
              if (path.endsWith('/parents/link-requests')) return reply([]);
              if (path.endsWith('/children/a/overview')) {
                await Future<void>.delayed(const Duration(milliseconds: 600));
                return reply(overview('Amal', 'Fall 2026'));
              }
              return reply(overview('Basel', 'Fall 2027'));
            }));
  });
}
