import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

void main() {
  testWidgets(
      'inbox scrolling retains story state and does not refetch its feed or ad',
      (tester) async {
    ApiClient.instance.clearCache();
    AuthSession.instance.token = 'scroll-stability';
    var storyReads = 0, bannerReads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pumpAndSettle();
      expect(find.text('Inbox advert'), findsOneWidget);
      final original = tester.state(find.byType(StudentStories));
      final reads = storyReads;
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(identical(tester.state(find.byType(StudentStories)), original),
          isTrue);
      expect(storyReads, reads);
      expect(bannerReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final route = request.url.path;
              Object data = {};
              if (route.endsWith('/banners')) {
                bannerReads++;
                data = [
                  {
                    'title': 'Inbox advert',
                    'placement': 'community',
                    'actionLabel': ''
                  }
                ];
              } else if (route.endsWith('/conversations')) {
                data = {
                  'conversations': [
                    for (var i = 0; i < 40; i++)
                      {
                        'contact': {
                          '_id': 'contact-$i',
                          'name': 'Student $i',
                          'avatar': ''
                        },
                        'unreadCount': 0,
                        'lastMessage': {
                          '_id': 'message-$i',
                          'body': 'Hello',
                          'createdAt': '2026-10-31T10:00:00Z'
                        },
                      }
                  ]
                };
              } else if (route.endsWith('/stories')) {
                storyReads++;
                data = {'stories': [], 'nextCursor': null};
              } else if (route.endsWith('/stories/progress')) {
                data = {'total_points': 0, 'streak_days': 0};
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json'});
            }));
    AuthSession.instance.token = null;
    ApiClient.instance.clearCache();
  });
}
