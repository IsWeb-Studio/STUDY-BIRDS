import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/stories/student_stories.dart';
import 'package:study_birds/core/widgets/state_widgets.dart';

http.Response reply(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> stories(String name) => {
      'stories': [
        {
          'id': 'story',
          'author': {'id': 'student', 'name': name},
          'text': 'Study day',
          'expiresAt':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String()
        },
      ]
    };
Map<String, dynamic> inbox(String name) => {
      'conversations': [
        {
          'contact': {'_id': 'peer', 'name': name},
          'unreadCount': 0,
          'lastMessage': {
            '_id': 'message',
            'body': 'hello',
            'createdAt': DateTime.now().toIso8601String()
          }
        },
      ]
    };

void main() {
  setUp(() {
    AuthSession.instance.token = 'loading-test';
    ApiClient.instance.clearCache();
  });
  tearDown(() {
    AuthSession.instance.token = null;
    ApiClient.instance.clearCache();
  });

  testWidgets('initial community skeleton matches story circles and inbox rows',
      (tester) async {
    final feed = Completer<http.Response>(), chats = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final placeholders =
          tester.widgetList<SkeletonBox>(find.byType(SkeletonBox));
      expect(placeholders.any((s) => s.width == 66 && s.borderRadius == 33),
          isTrue);
      expect(placeholders.any((s) => s.width == 44 && s.borderRadius == 22),
          isTrue);
      feed.complete(reply(stories('Loaded story')));
      chats.complete(reply(inbox('Loaded chat')));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('Loaded story'), findsOneWidget);
      expect(find.text('Loaded chat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((r) =>
            r.url.path.endsWith('/stories') ? feed.future : chats.future));
  });

  testWidgets('one page refresh updates stories and chats and waits for both',
      (tester) async {
    var refresh = false, finished = false;
    var feedRequests = 0, inboxRequests = 0;
    final feed = Completer<http.Response>(), chats = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pumpAndSettle();
      refresh = true;
      final state =
          tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
      final refreshing = state.show().then((_) => finished = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(feedRequests, 2);
      expect(inboxRequests, 2);
      expect(find.text('Old story'), findsOneWidget);
      expect(find.text('Old chat'), findsOneWidget);
      feed.complete(reply(stories('New story')));
      await tester.pump();
      expect(finished, isFalse);
      chats.complete(reply(inbox('New chat')));
      await tester.pumpAndSettle();
      await refreshing;
      expect(finished, isTrue);
      expect(find.text('New story'), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('/stories')) {
                feedRequests++;
                return refresh ? await feed.future : reply(stories('Old story'));
              }
              inboxRequests++;
              return refresh ? await chats.future : reply(inbox('Old chat'));
            }));
  });

  testWidgets('stories render without waiting for a separate points request',
      (tester) async {
    var progressRequests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StudentStories(showCommunityButton: false))));
      await tester.pumpAndSettle();
      expect(find.text('Fast stories'), findsOneWidget);
      expect(progressRequests, 0);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/stories/progress')) {
                progressRequests++;
                return Completer<http.Response>().future;
              }
              return reply(stories('Fast stories'));
            }));
  });

  testWidgets(
      'cached inbox and stories display before slow network replies, then refresh',
      (tester) async {
    ApiClient.instance.rememberSnapshot('/stories', stories('Cached story'),
        token: AuthSession.instance.token);
    ApiClient.instance.rememberSnapshot(
        '/mobile-workspace/conversations', inbox('Cached chat'),
        token: AuthSession.instance.token);
    final feed = Completer<http.Response>(), chats = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pump();
      expect(find.text('Cached story'), findsOneWidget);
      expect(find.text('Cached chat'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      feed.complete(reply(stories('Fresh story')));
      chats.complete(reply(inbox('Fresh chat')));
      await tester.pumpAndSettle();
      expect(find.text('Fresh story'), findsOneWidget);
      expect(find.text('Fresh chat'), findsOneWidget);
      expect(find.text('Cached chat'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) => request.url.path.endsWith('/stories')
            ? feed.future
            : chats.future));
  });

  test(
      'snapshots are session-isolated and old requests cannot restore cleared chat history',
      () async {
    final api =
        ApiClient.forTesting(MockClient((_) async => reply({'deleted': true})));
    api.rememberSnapshot(
        '/mobile-workspace/conversations', inbox('Private chat'),
        token: 'student-a');
    expect(api.snapshot('/mobile-workspace/conversations', token: 'student-b'),
        isNull);
    final copy = api.snapshot('/mobile-workspace/conversations',
        token: 'student-a') as Map;
    (copy['conversations'] as List).clear();
    expect(
        (api.snapshot('/mobile-workspace/conversations',
                token: 'student-a')['conversations'] as List)
            .length,
        1);
    final oldVersion = api.snapshotVersion;
    await api.delete('/mobile-workspace/conversations/peer',
        token: 'student-a');
    api.rememberSnapshot(
        '/mobile-workspace/conversations', inbox('Deleted chat'),
        token: 'student-a', version: oldVersion);
    expect(api.snapshot('/mobile-workspace/conversations', token: 'student-a'),
        isNull);
    api.rememberSnapshot('/stories', stories('Old account'),
        token: 'student-a');
    api.clearCache();
    expect(api.snapshot('/stories', token: 'student-a'), isNull);
  });

  test(
      'an inbox reply arriving after deletion cannot repopulate the screen cache',
      () async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final old = communityInbox();
      await Future<void>.delayed(Duration.zero);
      await ApiClient.instance.delete('/mobile-workspace/conversations/peer',
          token: AuthSession.instance.token);
      pending.complete(reply(inbox('Deleted history')));
      await old;
      expect(
          ApiClient.instance.snapshot('/mobile-workspace/conversations',
              token: AuthSession.instance.token),
          isNull);
    },
        () => MockClient((request) => request.method == 'GET'
            ? pending.future
            : Future.value(reply({'deleted': true}))));
  });
}
