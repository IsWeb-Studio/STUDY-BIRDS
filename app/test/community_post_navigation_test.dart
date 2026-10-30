import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_public_profile.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';

void main() {
  final post = <String, dynamic>{
    '_id': 'post-one',
    'title': 'Study plans',
    'body': 'The original post',
    'author': {'_id': 'peer', 'name': 'Sara', 'role': 'student'},
    'commentCount': 1,
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({'community_terms_v1:me': true});
    ApiClient.instance.clearCache();
    AuthSession.instance.token = 'navigation-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'me', name: 'Me', email: 'me@example.test', role: UserRole.student);
  });
  tearDown(() {
    ApiClient.instance.clearCache();
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  Future<void> exercise(WidgetTester tester, Future<void> Function() body,
      {void Function(http.Request)? onRequest}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: StudentCommunityScreen(embedded: true)));
      await tester.pumpAndSettle();
      await body();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async {
              onRequest?.call(r);
              Object data = [];
              if (r.url.path.endsWith('/community/status')) {
                data = {'suspended': false};
              }
              if (r.url.path.endsWith('/community/posts')) data = [post];
              if (r.url.path.endsWith('/community/posts/post-one')) {
                data = {
                  'post': post,
                  'comments': [
                    {
                      '_id': 'comment-one',
                      'body': 'A reply from someone else',
                      'author': {'_id': 'other', 'name': 'Reply author'}
                    }
                  ]
                };
              }
              if (r.url.path.endsWith('/friends/peer/profile')) {
                data = {
                  'id': 'peer',
                  'name': 'Sara',
                  'relation': 'none',
                  'stories': []
                };
              }
              if (r.method == 'POST') data = {'ok': true};
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  }

  testWidgets(
      'author opens their profile and a profile post opens the post, not a reply',
      (tester) async {
    String? authorFilter;
    await exercise(tester, () async {
      await tester.tap(find.text('Sara'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentPublicProfileScreen), findsOneWidget);
      expect(find.byType(CommunityThreadScreen), findsNothing);
      expect(authorFilter, 'peer');
      expect(find.byIcon(Icons.auto_stories_outlined), findsNothing);
      final grid = tester
          .widget<GridView>(find.byKey(const ValueKey('profile-post-grid')));
      expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          3);
      await tester
          .ensureVisible(find.byKey(const ValueKey('profile-post-post-one')));
      await tester.tap(find.byKey(const ValueKey('profile-post-post-one')));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityThreadScreen), findsOneWidget);
      expect(find.text('The original post'), findsOneWidget);
      expect(find.text('A reply from someone else'), findsOneWidget);
    }, onRequest: (r) {
      if (r.url.path.endsWith('/community/posts')) {
        authorFilter = r.url.queryParameters['author'];
      }
    });
  });

  testWidgets('comments and sending a reply stay inside the community feed',
      (tester) async {
    String? submitted;
    await exercise(tester, () async {
      await tester.tap(find.byKey(const ValueKey('feed-comments-post-one')));
      await tester.pumpAndSettle();
      expect(find.byType(StudentCommunityScreen), findsOneWidget);
      expect(
          tester
              .widget<CommunityThreadScreen>(find.byType(CommunityThreadScreen))
              .inline,
          isTrue);
      expect(find.text('The original post'), findsOneWidget);
      expect(find.text('A reply from someone else'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'My inline reply');
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('Send'));
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(submitted, 'My inline reply');
      expect(find.byType(StudentCommunityScreen), findsOneWidget);
    }, onRequest: (r) {
      if (r.method == 'POST' && r.url.path.endsWith('/comments')) {
        submitted = jsonDecode(r.body)['body'];
      }
    });
  });
}
