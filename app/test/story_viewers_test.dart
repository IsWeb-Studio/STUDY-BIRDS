import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/story_loading_indicator.dart';
import 'package:study_birds/screens/stories/story_viewers_screen.dart';
import 'package:study_birds/screens/stories/student_stories.dart';
import 'story_viewer_test.dart' show story, json, open;

void main() {
  setUp(() {
    AuthSession.instance.token = 'viewers-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'other',
        name: 'Owner',
        email: 'owner@example.test',
        role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });
  testWidgets(
      'owner opens full viewer page, loads more and story pauses until returning',
      (tester) async {
    await http.runWithClient(() async {
      await open(tester, [story('own')]);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('3 مشاهد'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('story-viewers-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StoryViewersScreen), findsOneWidget);
      expect(find.text('Viewer One'), findsOneWidget);
      await tester.tap(find.text('عرض المزيد'));
      await tester.pump();
      expect(find.text('Viewer Two'), findsOneWidget);
      expect(find.text('Viewer Three'), findsOneWidget);
      expect(find.text('عرض المزيد'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
      expect(find.byType(StoryViewersScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(StoryViewersScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StoryViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/updates')) {
                return json({
                  'updates': [
                    {'id': 'own', 'loveCount': 0, 'viewCount': 3}
                  ]
                });
              }
              if (request.url.path.endsWith('/viewers')) {
                return json({
                  'total': 3,
                  'viewers': request.url.queryParameters['before'] == null
                      ? [
                          {'id': '1', 'name': 'Viewer One', 'avatar': ''}
                        ]
                      : [
                          {'id': '2', 'name': 'Viewer Two', 'avatar': ''},
                          {'id': '3', 'name': 'Viewer Three', 'avatar': ''}
                        ],
                  'nextCursor': request.url.queryParameters['before'] == null
                      ? 'next'
                      : null
                });
              }
              return json({'seen': true});
            }));
  });
  testWidgets(
      'viewer refresh failure can retry even after all pages were loaded',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: StoryViewersScreen(storyId: 'own')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Viewer One'), findsOneWidget);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 3);
      expect(find.text('إعادة المحاولة'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              calls++;
              return calls == 2
                  ? json({'message': 'Disconnected'}, 400)
                  : json({
                      'total': 1,
                      'viewers': [
                        {'id': '1', 'name': 'Viewer One', 'avatar': ''}
                      ],
                      'nextCursor': null
                    });
            }));
  });
  testWidgets('viewers control is hidden on another person’s story',
      (tester) async {
    AuthSession.instance.currentUser = const AuthUser(
        id: 'someone',
        name: 'Guest',
        email: 'guest@example.test',
        role: UserRole.student);
    await http.runWithClient(() async {
      await open(tester, [story('other-story')]);
      expect(find.byKey(const ValueKey('story-viewers-button')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => json({'seen': true})));
  });
  testWidgets(
      'publishing uses segmented loading, preserves errors and permits retry',
      (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StoryComposer()));
      await tester.enterText(find.byType(TextField), 'My story');
      await tester.ensureVisible(find.text('نشر الستوري'));
      await tester.tap(find.text('نشر الستوري'));
      await tester.pump();
      expect(find.byType(StoryLoadingIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('جارٍ النشر…'), findsOneWidget);
      pending.complete(json({'message': 'Upload unavailable'}, 503));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('نشر الستوري'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) => pending.future));
  });
}
