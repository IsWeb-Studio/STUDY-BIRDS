import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';

http.Response json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() => AuthSession.instance.token = 'tok');
  tearDown(() => AuthSession.instance.token = null);

  testWidgets(
      'a long conversation is built lazily and shows the newest message first',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final messages = [
      for (var i = 1; i <= 400; i++)
        {'_id': 'm$i', 'sender': 'adv', 'body': 'message-$i', 'createdAt': '2026-01-01T10:00:00Z'}
    ];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ConversationThreadScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sara Advisor'));
      await tester.pumpAndSettle();

      expect(find.text('message-400'), findsOneWidget, reason: 'newest is at the bottom');
      expect(find.text('message-1'), findsNothing, reason: 'old bubbles are not built');
      final built = find.textContaining('message-').evaluate().length;
      expect(built, lessThan(40), reason: 'only visible bubbles exist, not 400');
      expect(tester.takeException(), isNull);

      // Unmount so the stream-reconnect timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/mobile-workspace/contacts')) {
            return json([{'_id': 'adv', 'name': 'Sara Advisor'}]);
          }
          if (path.endsWith('/mobile-workspace/messages')) return json(messages);
          return json({});
        }));
  });
}
