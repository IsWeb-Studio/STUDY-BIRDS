import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';

void main() {
  tearDown(() { AuthSession.instance.token = null; AuthSession.instance.currentUser = null; });
  for (final fail in [false, true]) {
    testWidgets('staff status update ${fail ? "preserves old state on failure" : "saves and reopens a closed ticket"}', (tester) async {
      AuthSession.instance.token = 'staff-ticket';
      AuthSession.instance.currentUser = const AuthUser(id: 'staff', name: 'Staff', email: 'staff@test.example', role: UserRole.admin);
      var writes = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: SupportTicketDetailScreen(ticket: {
          '_id': 'ticket', 'subject': 'Help', 'message': 'Original question', 'status': 'closed', 'replies': [],
        })));
        await tester.pumpAndSettle();
        expect(find.text('Original question'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('قيد المعالجة').last);
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(find.byKey(ValueKey('ticket-status-${fail ? "closed" : "in-progress"}')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((request) async {
        writes++;
        expect(request.method, 'PATCH');
        expect(request.url.path, endsWith('/admin/support-tickets/ticket/reply'));
        expect(jsonDecode(request.body)['status'], 'in-progress');
        return http.Response(jsonEncode(fail ? {'message': 'Save failed'} : {
          '_id': 'ticket', 'subject': 'Help', 'status': 'in-progress', 'replies': [],
        }), fail ? 503 : 200);
      }));
    });
  }
  testWidgets('students cannot change staff status or reply to a closed ticket', (tester) async {
    AuthSession.instance.currentUser = const AuthUser(id: 'student', name: 'Student', email: 's@test.example', role: UserRole.student);
    await tester.pumpWidget(const MaterialApp(home: SupportTicketDetailScreen(ticket: {
      '_id': 'ticket', 'subject': 'Help', 'status': 'closed', 'replies': [],
    })));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
