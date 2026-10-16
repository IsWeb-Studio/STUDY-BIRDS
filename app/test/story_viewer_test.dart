import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/story_viewer.dart';

StudentStory story(String id, {int count = 0}) => StudentStory.fromJson({
      'id': id,
      'text': 'Story $id',
      'imageUrl': '',
      'loveCount': count,
      'author': {
        'id': 'other',
        'name': 'Student',
        'avatar': '',
        'total_points': 0
      },
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
http.Response json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
Future<void> open(WidgetTester tester, List<StudentStory> stories,
    {Duration duration = const Duration(seconds: 8)}) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => StoryViewer(
                          stories: stories,
                          onSeen: (_) {},
                          storyDuration: duration))),
                  child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  setUp(() {
    AuthSession.instance.token = 'story-viewer-test';
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });
  test('default image and text duration is five seconds', () {
    expect(StoryViewer(stories: [story('a')], onSeen: (_) {}).storyDuration,
        const Duration(seconds: 5));
  });
  testWidgets('own story accepts a love through the same wide button',
      (tester) async {
    final previous = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
        id: 'other', name: 'Me', email: 'me@example.test', role: UserRole.student);
    addTearDown(() => AuthSession.instance.currentUser = previous);
    var calls = 0;
    await http.runWithClient(() async {
      await open(tester, [story('self')]);
      await tester.tap(find.byKey(const ValueKey('story-love-button')));
      await tester.pump();
      expect(calls, 1);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((req) async {
      if (req.url.path.endsWith('/love')) {
        calls++;
        return json({'loveCount': 1, 'awarded': 0});
      }
      return json({'seen': true});
    }));
  });
  testWidgets(
      'double tap sends one love without advancing and keeps a small icon with a wide target',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await open(tester, [story('a'), story('b')]);
      final finder = find.byKey(const ValueKey('story-love-button'));
      expect(tester.getRect(finder).height, greaterThanOrEqualTo(72));
      expect(tester.getRect(finder).width, greaterThanOrEqualTo(144));
      expect(tester.widget<Icon>(find.byIcon(Icons.favorite_border)).size, 20);
      await tester.tap(find.text('Story a'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Story a'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Story a'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      // A second double tap must never toggle or send another love.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Story a'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Story a'));
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((req) async {
              if (req.url.path.endsWith('/love')) {
                calls++;
                return json({'loveCount': 1});
              }
              return json({'seen': true});
            }));
  });
  testWidgets(
      'left tap advances, right tap goes back, and taps around the heart still love',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await open(tester, [story('a'), story('b')]);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.byTooltip('السابقة'), findsNothing);
      final content = tester.getRect(find.byKey(const ValueKey('story-content')));
      // Use physical screen coordinates, independent of Arabic/English layout.
      await tester.tapAt(Offset(content.left + 30, content.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Story b'), findsOneWidget);
      await tester.tapAt(Offset(content.right - 30, content.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Story a'), findsOneWidget);
      final button =
          tester.getRect(find.byKey(const ValueKey('story-love-button')));
      await tester.tapAt(Offset(button.left + 10, button.center.dy));
      await tester.pump();
      expect(calls, 1);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((req) async {
              if (req.url.path.endsWith('/love')) {
                calls++;
                return json({'loveCount': 1});
              }
              return json({'seen': true});
            }));
  });
  testWidgets(
      'a failed love restores the previous count and leaves retry enabled',
      (tester) async {
    await http.runWithClient(() async {
      await open(tester, [story('a', count: 2)]);
      final finder = find.byKey(const ValueKey('story-love-button'));
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.widgetWithText(TextButton, '2'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(tester.widget<TextButton>(finder).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((req) async => req.url.path.endsWith('/love')
            ? json({}, 503)
            : json({'seen': true})));
  });
  testWidgets(
      'large love button updates instantly, deduplicates taps and reconciles server count',
      (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(() async {
      await open(tester, [story('a')]);
      final finder = find.byKey(const ValueKey('story-love-button'));
      final rect = tester.getRect(finder);
      expect(rect.height, greaterThanOrEqualTo(64));
      expect(rect.width, greaterThanOrEqualTo(116));
      final tap = tester.widget<TextButton>(finder).onPressed!;
      tap();
      tap();
      tap();
      await tester.pump();
      expect(calls, 1);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.widgetWithText(TextButton, '1'), findsOneWidget);
      pending.complete(json({'loveCount': 3, 'loved': true}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.widgetWithText(TextButton, '3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((req) async {
              if (req.url.path.endsWith('/love')) {
                calls++;
                return await pending.future;
              }
              return json({'seen': true});
            }));
  });
  testWidgets(
      'live loves arrive without reopening and the timer advances then closes',
      (tester) async {
    var count = 0;
    var polls = 0;
    await http.runWithClient(() async {
      await open(tester, [story('a'), story('b')]);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(polls, 1);
      count = 4;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.widgetWithText(TextButton, '4'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('story-timer-0')));
      expect(bar.value, greaterThan(.4));
      expect(bar.color, Colors.pinkAccent);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Story b'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
      expect(find.byType(StoryViewer), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((req) async {
              if (req.url.path.endsWith('/updates')) {
                polls++;
                return json({
                  'updates': [
                    {
                      'id': req.url.queryParameters['ids'],
                      'loveCount': count,
                      'loved': false
                    }
                  ]
                });
              }
              return json({'seen': true});
            }));
  });
  testWidgets('backgrounding pauses playback and stops live requests',
      (tester) async {
    var polls = 0;
    await http.runWithClient(() async {
      await open(tester, [story('a')]);
      await tester.pump(const Duration(seconds: 1));
      final before = tester
          .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('story-timer-0')))
          .value!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 12));
      expect(find.byType(StoryViewer), findsOneWidget);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('story-timer-0')))
              .value,
          before);
      expect(polls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
      expect(find.byType(StoryViewer), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((req) async {
              if (req.url.path.endsWith('/updates')) {
                polls++;
                return json({
                  'updates': [
                    {'id': 'a', 'loveCount': 0}
                  ]
                });
              }
              return json({'seen': true});
            }));
  });
}
