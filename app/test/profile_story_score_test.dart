import 'package:study_birds/core/widgets/bird_points.dart';
import 'package:study_birds/screens/stories/student_stories.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/profile_account/profile_story_score.dart';
import 'package:study_birds/screens/profile_account/profile_account_screens.dart';

void main() {
  testWidgets('profile back arrow returns to the page that opened it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen())),
                    child: const Text('Open profile'),
                  ),
                )),
      ));
      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.text('Open profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((_) async => http.Response('{}', 200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  testWidgets('fixed bird badge opens progress instead of an emoji selector',
      (tester) async {
    AuthSession.instance.token = 'score-test';
    addTearDown(() => AuthSession.instance.token = null);
    final writes = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProfileStoryScore())));
      await tester.pumpAndSettle();
      expect(find.text('6500'), findsOneWidget);
      expect(find.byType(BirdPointsIcon), findsOneWidget);
      await tester.tap(find.byType(ProfileStoryScore));
      await tester.pumpAndSettle();
      expect(find.byType(StoryProgressSheet), findsOneWidget);
      expect(find.text('6500 / 10,000'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method != 'GET') writes.add(request.url.path);
              return http.Response(
                  jsonEncode({
                    'total_points': 6500,
                    'streak_days': 7,
                    'scoreEmoji': '\u{1f48e}'
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets(
      'profile score is physically left of the avatar in both directions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'profile-placement-test';
    final previous = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
        id: 'student',
        name: 'Student',
        email: 'student@example.test',
        role: UserRole.student);
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = previous;
    });
    await http.runWithClient(() async {
      for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
        await tester.pumpWidget(MaterialApp(
            home: Directionality(
                textDirection: direction, child: const ProfileScreen())));
        await tester.pumpAndSettle();
        final score = tester.getRect(find.byType(ProfileStoryScore));
        final avatar = tester.getRect(find.byType(CircleAvatar).first);
        final changePhoto = tester.getRect(find.text('تغيير الصورة الشخصية'));
        expect(score.right, lessThan(avatar.left));
        expect(score.right, lessThan(changePhoto.left));
        expect(find.text('200000'), findsOneWidget);
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
        () => MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('/stories/progress')
                ? {'total_points': 200000, 'scoreEmoji': '🔥'}
                : {'phone': '123', 'nationality': 'Turkey'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
