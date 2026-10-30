import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/contact_profile_screen.dart';

void main() {
  testWidgets('authorized support contact opens a safe employee profile',
      (tester) async {
    const userId = '000000000000000000000001';
    AuthSession.instance.token = 'contact-profile-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: '000000000000000000000002',
      name: 'Student',
      email: 'student@example.test',
      role: UserRole.student,
    );
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    final requestedPaths = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: Center(
            child: ContactProfileLink(
              userId: userId,
              child: Text('Open assigned support contact'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open assigned support contact'));
      await tester.pumpAndSettle();

      expect(find.text('Taylor Support'), findsOneWidget);
      expect(find.text('Support staff'), findsOneWidget);
      expect(find.text('private@example.test'), findsNothing);
      expect(requestedPaths, ['/mobile-workspace/contacts/$userId']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              requestedPaths.add(request.url.path.replaceFirst('/api', ''));
              expect(request.headers['authorization'],
                  'Bearer contact-profile-test');
              return http.Response(
                jsonEncode({
                  '_id': userId,
                  'name': 'Taylor Support',
                  'role': 'employee',
                  'avatar': '',
                  'email': 'private@example.test',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }));
  });

  testWidgets('community contacts use community profile authorization',
      (tester) async {
    const userId = '000000000000000000000003';
    AuthSession.instance.token = 'community-profile-test';
    addTearDown(() => AuthSession.instance.token = null);
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: Center(
            child: ContactProfileLink(
              userId: userId,
              communityMode: true,
              child: Text('Open community contact'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open community contact'));
      await tester.pumpAndSettle();

      expect(find.text('Taylor University'), findsOneWidget);
      expect(requests.single.queryParameters['community'], '1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                jsonEncode({
                  '_id': userId,
                  'name': 'Taylor University',
                  'role': 'university',
                  'avatar': '',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }));
  });

  testWidgets('revoked contact stays unavailable', (tester) async {
    AuthSession.instance.token = 'contact-profile-test';
    addTearDown(() => AuthSession.instance.token = null);

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        home: ContactProfileScreen(userId: '000000000000000000000001'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('This profile is unavailable to your account.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => http.Response(
              jsonEncode({'message': 'This contact is unavailable'}),
              403,
              headers: {'content-type': 'application/json'},
            )));
  });
}
