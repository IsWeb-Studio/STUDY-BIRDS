import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_profile_link.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/community/student_public_profile.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';
import 'package:study_birds/screens/stories/story_viewer.dart';

http.Response response(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> profile(String relation) => {
      'id': 'peer',
      'name': 'Sara',
      'avatar': '',
      'total_points': 200000,
      'streak_days': 7,
      'friendCount': 12,
      'relation': relation,
      'canMessage': relation != 'self',
      'canViewStories': ['self', 'friends'].contains(relation),
      'stories': [],
    };

void main() {
  setUp(() => AuthSession.instance.token = 'public-profile');
  tearDown(() => AuthSession.instance.token = null);

  testWidgets('community conversation avatar opens that student profile',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pumpAndSettle();
      final avatar = find.byWidgetPredicate(
          (w) => w is StudentProfileLink && w.studentId == 'peer');
      expect(avatar, findsOneWidget);
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(find.byType(StudentPublicProfileScreen), findsOneWidget);
      expect(find.byType(ConversationThreadScreen), findsNothing);
      expect(find.text('مراسلة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path.endsWith('/profile')) return response(profile('none'));
              if (path.endsWith('/conversations'))
                return response({
                  'unreadTotal': 0,
                  'conversations': [
                    {
                      'contact': {'_id': 'peer', 'name': 'Sara'},
                      'unreadCount': 0,
                      'lastMessage': {
                        '_id': 'msg',
                        'body': 'hello',
                        'createdAt': '2026-10-16T09:00:00Z'
                      }
                    },
                  ]
                });
              if (path.endsWith('/stories')) return response({'stories': []});
              return response({});
            }));
  });

  testWidgets('avatar opens one profile and allows messaging a non-friend',
      (tester) async {
    var loads = 0;
    var relation = 'none';
    final requests = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: StudentProfileLink(
                  studentId: 'peer', child: CircleAvatar(child: Text('S'))))));
      await tester.tap(find.text('S'));
      await tester.tap(find.text('S'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(StudentPublicProfileScreen), findsOneWidget);
      expect(loads, 1, reason: 'double tap cannot stack profile pages');
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('إضافة صديق'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.text('مراسلة'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationThreadScreen), findsOneWidget);
      expect(requests, contains('/api/mobile-workspace/messages'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة صديق'));
      await tester.pumpAndSettle();
      expect(find.text('إلغاء الطلب'), findsOneWidget);
      expect(requests, contains('/api/friends/peer/request'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              requests.add(path);
              if (path.endsWith('/profile')) {
                loads++;
                return response(profile(relation));
              }
              if (path.endsWith('/request')) {
                relation = 'outgoing';
                return response({'relation': relation});
              }
              if (path.endsWith('/messages')) return response([]);
              return response({});
            }));
  });

  testWidgets(
      'accepting friendship reveals stories that open in the story viewer',
      (tester) async {
    var relation = 'incoming';
    final story = {
      'id': 'story',
      'author': {'id': 'peer', 'name': 'Sara'},
      'text': 'Study day',
      'expiresAt':
          DateTime.now().add(const Duration(hours: 12)).toIso8601String()
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: StudentPublicProfileScreen(studentId: 'peer')));
      await tester.pumpAndSettle();
      expect(find.text('Study day'), findsNothing);
      await tester.tap(find.text('قبول الصداقة'));
      await tester.pumpAndSettle();
      expect(find.text('Study day'), findsOneWidget);
      await tester.ensureVisible(find.text('Study day'));
      await tester.tap(find.text('Study day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(StoryViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path.endsWith('/accept')) {
                relation = 'friends';
                return response({'relation': relation});
              }
              if (path.endsWith('/profile'))
                return response({
                  ...profile(relation),
                  'storyCount': relation == 'friends' ? 1 : null,
                  'stories': relation == 'friends' ? [story] : []
                });
              if (path.endsWith('/updates'))
                return response({'updates': [], 'progress': {}});
              return response({});
            }));
  });

  testWidgets(
      'own public profile fits a narrow phone and cannot message itself',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: StudentPublicProfileScreen(studentId: 'me')));
      await tester.pumpAndSettle();
      expect(find.text('ملفك العام'), findsOneWidget);
      expect(find.text('مراسلة'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => response(profile('self'))));
  });
}
