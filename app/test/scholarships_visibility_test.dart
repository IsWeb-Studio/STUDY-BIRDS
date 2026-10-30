import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/admin_scholarships_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/countries_scholarships_screens.dart';

void main() {
  tearDown(() {
    AuthSession.instance.currentUser = null;
    AuthSession.instance.token = null;
  });

  testWidgets('new admin scholarships are published by default',
      (tester) async {
    AuthSession.instance.currentUser = const AuthUser(
      id: 'admin',
      name: 'Admin',
      email: 'admin@example.test',
      role: UserRole.admin,
    );
    AuthSession.instance.token = 'admin-token';
    Map<String, dynamic>? created;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminScholarshipsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);
      await tester.enterText(find.byType(TextField).first, 'Visible grant');
      await tester.ensureVisible(find.byType(ElevatedButton).last);
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(created?['title'], 'Visible grant');
      expect(created?['active'], isTrue);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') return http.Response('[]', 200);
              if (request.method == 'POST') {
                created = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response(
                    jsonEncode({'_id': 'grant-1', ...created!}), 201);
              }
              return http.Response('{}', 200);
            }));
  });

  testWidgets('student can refresh Explore and see a newly published grant',
      (tester) async {
    AuthSession.instance.currentUser = const AuthUser(
      id: 'student',
      name: 'Student',
      email: 'student@example.test',
      role: UserRole.student,
    );
    AuthSession.instance.token = 'student-token';
    var publicListRequests = 0;

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ScholarshipsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Newly published grant'), findsNothing);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(publicListRequests, 2);
      expect(find.text('Newly published grant'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/mine')) {
                return http.Response('[]', 200);
              }
              if (request.url.path.endsWith('/scholarships')) {
                publicListRequests++;
                return http.Response(
                  publicListRequests == 1
                      ? '[]'
                      : jsonEncode([
                          {
                            '_id': 'grant-2',
                            'title': 'Newly published grant',
                            'active': true,
                          }
                        ]),
                  200,
                );
              }
              return http.Response('{}', 200);
            }));
  });
}
