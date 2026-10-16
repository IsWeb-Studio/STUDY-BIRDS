import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/stories/story_viewer.dart';
import 'package:study_birds/screens/stories/student_stories.dart'
    show StoryRing;

void main() {
  testWidgets(
      'community has story circles, pull refresh and one new-chat action',
      (tester) async {
    AuthSession.instance.token = 'community-controls';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pumpAndSettle();
      expect(find.text('عرض الكل'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.edit_square), findsNothing);
      expect(find.text('محادثة جديدة'), findsOneWidget);
      expect(find.text('مجتمع الطلاب'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.tap(find.byType(StoryRing));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StoryViewer), findsOneWidget);
      expect(find.text('Circle story'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final Object data = request.url.path.endsWith('/stories')
                  ? {
                      'stories': [
                        {
                          'id': 'story-one',
                          'text': 'Circle story',
                          'author': {
                            'id': 'student-one',
                            'name': 'Student One'
                          },
                          'expiresAt': DateTime.now()
                              .add(const Duration(hours: 1))
                              .toIso8601String()
                        }
                      ],
                      'nextCursor': null,
                    }
                  : request.url.path.endsWith('/conversations')
                      ? {'conversations': [], 'unreadTotal': 0}
                      : {'seen': true};
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
