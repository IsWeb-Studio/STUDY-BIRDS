import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/admin_push_announcements_screen.dart';

void main() {
  setUp(() {
    AuthSession.instance.token = 'announcement-admin-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'admin',
        name: 'Admin',
        email: 'admin@example.test',
        role: UserRole.admin);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
    ApiClient.instance.clearCache();
  });
  http.Response reply(Object value, [int status = 200]) =>
      http.Response(jsonEncode(value), status,
          headers: {'content-type': 'application/json'});

  testWidgets(
      'explicit confirmation is required and retries preserve the campaign ID',
      (tester) async {
    final sends = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('en'), home: AdminPushAnnouncementsScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'App update');
      await tester.enterText(
          find.byType(TextField).at(1), 'New features available');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send to all'));
      await tester.tap(find.text('Send to all'));
      await tester.pumpAndSettle();
      expect(sends, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(sends, isEmpty);
      await tester.tap(find.text('Send to all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send now'));
      await tester.pumpAndSettle();
      expect(sends, hasLength(1));
      expect(find.textContaining('Unable to confirm sending'), findsOneWidget);
      final retry = find.text('Retry same announcement');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(sends, hasLength(2));
      expect(sends[0]['requestId'], sends[1]['requestId']);
      expect(find.textContaining('Accepted by push service'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return reply({'enabled': true, 'items': []});
              }
              sends.add(jsonDecode(request.body) as Map<String, dynamic>);
              return sends.length == 1
                  ? reply({'message': 'Synthetic timeout'}, 502)
                  : reply({'status': 'accepted'});
            }));
  });

  testWidgets('disabled provider never allows sending', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('en'), home: AdminPushAnnouncementsScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Title');
      await tester.enterText(find.byType(TextField).last, 'Message');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
    },
        () => MockClient(
            (request) async => reply({'enabled': false, 'items': []})));
  });

  testWidgets('non-admin has no composer or requests', (tester) async {
    AuthSession.instance.currentUser = const AuthUser(
        id: 'employee',
        name: 'Employee',
        email: 'employee@example.test',
        role: UserRole.employee);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: AdminPushAnnouncementsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    },
        () => MockClient((_) async {
              fail('Non-admin must not request announcements');
            }));
  });
}
