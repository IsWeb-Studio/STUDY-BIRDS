import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

void main() {
  setUp(() => AuthSession.instance.token = 'test');
  tearDown(() => AuthSession.instance.token = null);
  testWidgets(
      'community keeps stories above inbox and promotes incoming unread chat',
      (tester) async {
    var updated = false;
    final read = <String>[];
    Map<String, dynamic> row(String id, String name, String body, int unread) =>
        {
          'contact': {'_id': id, 'name': name},
          'unreadCount': unread,
          'lastMessage': {
            '_id': '$id${updated ? 2 : 1}',
            'sender': id,
            'body': body,
            'createdAt': '2026-10-16T10:00:00Z'
          }
        };
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pumpAndSettle();
      expect(find.byType(StudentStories), findsOneWidget);
      expect(find.text('مجتمع الطلاب'), findsOneWidget,
          reason: 'no nested community entry');
      expect(tester.getTopLeft(find.text('Sara')).dy,
          lessThan(tester.getTopLeft(find.text('Omar')).dy));
      updated = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Omar')).dy,
          lessThan(tester.getTopLeft(find.text('Sara')).dy));
      expect(find.text('new message'), findsOneWidget);
      expect(find.text('رسالة جديدة من Omar'), findsOneWidget);
      await tester.tap(find.text('Omar'));
      await tester.pumpAndSettle();
      expect(find.text('thread message'), findsOneWidget);
      expect(read, contains('omar'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              Object data = {};
              if (path.endsWith('/conversations'))
                data = {
                  'unreadTotal': updated ? 2 : 0,
                  'conversations': updated
                      ? [
                          row('omar', 'Omar', 'new message', 2),
                          row('sara', 'Sara', 'hello', 0)
                        ]
                      : [
                          row('sara', 'Sara', 'hello', 0),
                          row('omar', 'Omar', 'old', 0)
                        ]
                };
              if (path.endsWith('/stories'))
                data = {'stories': [], 'nextCursor': null};
              if (path.endsWith('/stories/progress'))
                data = {'total_points': 0, 'streak_days': 0};
              if (path.endsWith('/messages'))
                data = [
                  {
                    '_id': 'msg',
                    'sender': 'omar',
                    'body': 'thread message',
                    'createdAt': '2026-10-16T10:00:00Z'
                  }
                ];
              if (path.endsWith('/messages/read'))
                read.add('${jsonDecode(request.body)['sender']}');
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('dashboard community entry loads unread badge safely',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home:
              Scaffold(body: SizedBox(height: 122, child: CommunityEntry()))));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => http.Response('{"unreadTotal":3}', 200)));
  });
}
