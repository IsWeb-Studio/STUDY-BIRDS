import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';

void main() {
  setUp(() => AuthSession.instance.token = 'community-chat-scope-test');
  tearDown(() => AuthSession.instance.token = null);

  test('community inbox uses its isolated conversation channel', () async {
    late Uri requested;
    await http.runWithClient(() async {
      final result = await communityInbox();
      expect(result['conversations'], isEmpty);
      expect(requested.path, endsWith('/mobile-workspace/conversations'));
      expect(requested.queryParameters['community'], '1');
    },
        () => MockClient((request) async {
              requested = request.url;
              return http.Response(
                  jsonEncode({'conversations': [], 'unreadTotal': 0}), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets('new community chat lists cross-role community contacts',
      (tester) async {
    AuthSession.instance.currentUser = const AuthUser(
      id: 'university-community-test',
      name: 'Test University',
      email: 'university@example.test',
      role: UserRole.university,
    );
    addTearDown(() => AuthSession.instance.currentUser = null);
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey('community-new-chat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        requests.any((uri) =>
            uri.path.endsWith('/mobile-workspace/contacts') &&
            uri.queryParameters['community'] == '1'),
        isTrue,
      );
      expect(find.text('Community contact'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
        () => MockClient((request) async {
              requests.add(request.url);
              if (request.url.path.endsWith('/mobile-workspace/contacts')) {
                return http.Response(
                  jsonEncode([
                    {
                      '_id': 'community-contact-id',
                      'name': 'Community contact',
                      'role': 'employee',
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path
                  .endsWith('/mobile-workspace/conversations')) {
                return http.Response(
                  jsonEncode({'conversations': [], 'unreadTotal': 0}),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path.endsWith('/stories')) {
                return http.Response(jsonEncode({'stories': []}), 200,
                    headers: {'content-type': 'application/json'});
              }
              return http.Response('{}', 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets(
      'community thread scopes contacts while support default stays unchanged',
      (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: ConversationThreadScreen(communityMode: true),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requests.last.queryParameters['community'], '1');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(
        home: ConversationThreadScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requests.last.queryParameters.containsKey('community'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
        () => MockClient((request) async {
              requests.add(request.url);
              if (request.url.path.endsWith('/mobile-workspace/contacts')) {
                return http.Response('[]', 200,
                    headers: {'content-type': 'application/json'});
              }
              return http.Response('{}', 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
