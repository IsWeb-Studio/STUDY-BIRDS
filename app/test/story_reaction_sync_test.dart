import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/student_stories.dart';
import 'story_viewer_test.dart' as viewer;

http.Response reply(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final repo = StoriesRepository.instance;
  var session = 0;
  setUp(() => AuthSession.instance.token = 'reaction-sync-${session++}');
  tearDown(() {
    AuthSession.instance.token = null;
  });

  test('a stale poll cannot undo a pending or confirmed like', () async {
    final poll = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final updating = repo.updates(['one']);
      await started.future;
      await repo.love('one', previousCount: 4);
      poll.complete(reply({
        'updates': [
          {'id': 'one', 'loveCount': 4, 'loved': false}
        ]
      }));
      final data = await updating;
      expect(data['updates'][0]['loveCount'], 5);
      expect(data['updates'][0]['loved'], true);
      expect(repo.reactionFor('one'), (count: 5, loved: true));
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/updates')) {
                started.complete();
                return poll.future;
              }
              return reply({'loveCount': 5});
            }));
  });

  test(
      'failed like rolls back shared state and duplicate pending taps send one request',
      () async {
    final response = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(() async {
      final pending = repo.love('one', previousCount: 4);
      final failure = expectLater(pending, throwsException);
      expect(identical(repo.love('one', previousCount: 4), pending), true);
      expect(repo.reactionFor('one'), (count: 5, loved: true));
      response.complete(reply({'message': 'offline'}, 503));
      await failure;
      expect(repo.reactionFor('one'), (count: 4, loved: false));
      expect(calls, 1);
    },
        () => MockClient((_) {
              calls++;
              return response.future;
            }));
  });

  test('late like response does not populate another account', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = repo.love('one');
      AuthSession.instance.token = 'another-account';
      response.complete(reply({'loveCount': 8}));
      await pending;
      expect(repo.reactionFor('one'), isNull);
    }, () => MockClient((_) => response.future));
  });

  testWidgets(
      'story strip updates before the network completes and reconciles immediately',
      (tester) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StudentStories(compact: true))));
      await tester.pumpAndSettle();
      final total = find.byKey(const ValueKey('story-loves-peer'));
      expect(tester.widget<Text>(total).data, '0');
      final pending = repo.love('one', previousCount: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<Text>(total).data, '1');
      response.complete(reply({'loveCount': 3}));
      await pending;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<Text>(total).data, '3');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/love')) return response.future;
              if (request.url.path.endsWith('/stories')) {
                return reply({
                  'stories': [
                    {
                      'id': 'one',
                      'author': {'id': 'peer', 'name': 'Peer'},
                      'expiresAt': DateTime.now()
                          .add(const Duration(hours: 1))
                          .toIso8601String(),
                    }
                  ],
                  'nextCursor': null
                });
              }
              return reply({});
            }));
  });

  testWidgets(
      'reopening a stale story model already shows the confirmed heart without polling',
      (tester) async {
    await http.runWithClient(() async {
      await repo.love('reopened', previousCount: 0);
      await viewer.open(tester, [viewer.story('reopened')]);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.widgetWithText(TextButton, '6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async => request.url.path.endsWith('/love')
            ? reply({'loveCount': 6})
            : reply({'seen': true})));
  });
}
