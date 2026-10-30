import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/contact_profile_screen.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';

http.Response reply(Object body, [int status = 200]) => http.Response(jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});
const team = [
  {'_id': 'first-staff', 'name': 'First advisor'},
  {'_id': 'second-staff', 'name': 'Second advisor'},
];
void main() {
  setUp(() {
    AuthSession.instance.token = 'synthetic-my-team-chat';
    AuthSession.instance.currentUser = const AuthUser(id: 'student', name: 'Student', email: 'student@example.test', role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });
  for (final member in team) {
    testWidgets('team card opens and sends directly to ${member['_id']}', (tester) async {
      final recipients = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: MyTeamScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(member['name']!));
        await tester.pumpAndSettle();
        final screen = tester.widget<ConversationThreadScreen>(find.byType(ConversationThreadScreen));
        expect(screen.contactId, member['_id']);
        expect(screen.supportTeamOnly, isTrue);
        expect(find.byType(ContactProfileLink), findsOneWidget);
        await tester.tap(find.text(member['name']!));
        await tester.pumpAndSettle();
        expect(find.text('Support staff'), findsOneWidget);
        expect(find.text(member['name']!), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Hello advisor');
        await tester.tap(find.byTooltip('إرسال'));
        await tester.pumpAndSettle();
        expect(recipients, [member['_id']]);
        expect(find.text('Hello advisor'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/students/support-team')) return reply(team);
        if (request.url.path.endsWith('/mobile-workspace/contacts/${member['_id']}')) {
          return reply({
            '_id': member['_id'],
            'name': member['name'],
            'role': 'employee',
            'avatar': '',
          });
        }
        expect(request.url.path.endsWith('/contacts'), isFalse, reason: 'Direct navigation must not open the account directory');
        if (request.url.path.endsWith('/conversations/${member['_id']}')) return reply({'muted': false});
        if (request.url.path.endsWith('/messages') && request.method == 'GET') {
          expect(request.url.queryParameters['recipient'], member['_id']);
          return reply([]);
        }
        if (request.url.path.endsWith('/messages') && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map;
          recipients.add(body['recipient'] as String);
          return reply({'_id': 'sent', 'sender': 'student', 'recipient': body['recipient'], 'body': body['body'], 'createdAt': '2026-10-23T00:00:00Z'}, 201);
        }
        return reply({});
      }));
    });
  }
  testWidgets('revoked team contact shows server refusal instead of message history', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyTeamScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First advisor'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعذر تحميل الرسائل'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => request.url.path.endsWith('/students/support-team')
        ? reply(team) : reply({'message': 'This support contact is not assigned to this student'}, 403)));
  });
}
