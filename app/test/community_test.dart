import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';
import 'package:study_birds/screens/community/student_public_profile.dart';

http.Response reply(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

const me = {'_id': 'me', 'name': 'Me'};
const other = {'_id': 'other', 'name': 'Lina'};
const publicPost = {
  '_id': 'p1',
  'title': 'سكن قريب من الجامعة',
  'body': 'أين أجد سكنًا مناسبًا؟',
  'topic': 'housing',
  'commentCount': 1,
  'author': other,
  'studyField': {'_id': 'med', 'name': 'Medicine'},
  'createdAt': '2026-09-01T10:00:00Z',
};
const hiddenMine = {
  '_id': 'p2',
  'title': 'إعلان',
  'body': 'نص',
  'topic': 'other',
  'commentCount': 0,
  'status': 'hidden',
  'moderationNote': 'إعلان تجاري',
  'author': me,
  'createdAt': '2026-09-01T10:00:00Z',
};
const lookups = {
  '/api/content/countries': [
    {'_id': 'tr', 'name': 'Turkey'}
  ],
  '/api/universities': [
    {'_id': 'iu', 'name': 'Istanbul University', 'country': 'tr'}
  ],
  '/api/content/study-fields': [
    {'_id': 'med', 'name': 'Medicine'}
  ],
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('feed author avatar opens the topic; thread avatar opens profile', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityThreadScreen), findsOneWidget);
      expect(find.byType(StudentPublicProfileScreen), findsNothing);
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();
      expect(find.byType(StudentPublicProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((r) async {
      if (lookups.containsKey(r.url.path)) return reply(lookups[r.url.path]!);
      if (r.url.path.endsWith('/community/status')) return reply({'suspended': false});
      if (r.url.path.endsWith('/community/posts/p1')) return reply({'post': publicPost, 'comments': []});
      if (r.url.path.contains('/friends/')) return reply({'id': 'other', 'name': 'Lina', 'stories': []});
      return reply([publicPost]);
    }));
  });
  setUp(() {
    AuthSession.instance.token = 'test-session';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'me', name: 'Me', email: 'me@example.test', role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets(
      'feed filters by topic and study field; my posts show the hidden reason',
      (tester) async {
    phone(tester);
    final queries = <String>[];
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: StudentCommunityScreen()));
      await tester.pumpAndSettle();
      expect(find.text('سكن قريب من الجامعة'), findsOneWidget);
      expect(find.textContaining('Medicine'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'السكن'));
      await tester.pumpAndSettle();
      expect(queries.last, 'topic=housing');

      await tester.tap(find.text('تصفية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('كل التخصصات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicine').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();
      expect(Uri.splitQueryString(queries.last),
          {'topic': 'housing', 'studyField': 'med'});
      expect(find.text('تصفية (1)'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'مواضيعي'));
      await tester.pumpAndSettle();
      expect(queries.last, 'mine=1');
      expect(find.text('أخفاه فريق الإشراف — إعلان تجاري'), findsOneWidget);
      // A hidden post is not openable.
      await tester.tap(find.text('إعلان'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityThreadScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              // Lookups are public content; only community calls carry a token.
              if (lookups.containsKey(r.url.path)) {
                return reply(lookups[r.url.path]!);
              }
              expect(r.headers['authorization'], 'Bearer test-session');
              if (r.url.path == '/api/community/status') {
                return reply({'suspended': false});
              }
              expect(r.url.path, '/api/community/posts');
              queries.add(r.url.query);
              return reply(
                  r.url.query == 'mine=1' ? [hiddenMine] : [publicPost]);
            }));
  });

  testWidgets('a suspended student reads only and sees why', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: StudentCommunityScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('أنت موقوف عن النشر والتعليق والإبلاغ'),
          findsOneWidget);
      expect(find.textContaining('حتى يرفعه فريق الإشراف'), findsOneWidget);
      expect(find.textContaining('السبب: إساءة متكررة'), findsOneWidget);
      expect(find.text('موضوع جديد'), findsNothing);
      expect(find.text('سكن قريب من الجامعة'), findsOneWidget);

      await tester.tap(find.text('سكن قريب من الجامعة'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityThreadScreen), findsOneWidget);
      expect(find.text('إبلاغ'), findsNothing);
      expect(find.widgetWithText(TextField, 'أضف تعليقًا'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              if (lookups.containsKey(r.url.path)) {
                return reply(lookups[r.url.path]!);
              }
              if (r.url.path == '/api/community/status') {
                return reply({
                  'suspended': true,
                  'until': null,
                  'reason': 'إساءة متكررة'
                });
              }
              if (r.url.path == '/api/community/posts/p1') {
                return reply({'post': publicPost, 'comments': []});
              }
              expect(r.method, 'GET');
              return reply([publicPost]);
            }));
  });

  test('community errors explain blocked words and suspensions in Arabic', () {
    expect(communityError(const ApiException(422, 'x'), 'f'),
        'النص يحتوي كلمات غير مسموحة في المجتمع. عدّل النص وحاول مجددًا.');
    expect(communityError(const ApiException(403, 'x'), 'f'),
        'أنت موقوف حاليًا عن النشر في المجتمع.');
    expect(communityError(Exception('offline'), 'f'), 'f');
  });

  testWidgets(
      'composing requires title and body, sends tags and keeps input on failure',
      (tester) async {
    phone(tester);
    final bodies = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: CommunityComposeScreen(fields: [
        {'_id': 'med', 'name': 'Medicine'}
      ])));
      await tester.pumpAndSettle();
      FilledButton publish() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'نشر'));
      expect(publish().onPressed, isNull);
      await tester.enterText(
          find.widgetWithText(TextField, 'العنوان'), 'نصيحة');
      await tester.enterText(
          find.widgetWithText(TextField, 'النص'), 'ابدأ مبكرًا');
      await tester.pumpAndSettle();
      await tester.tap(find.text('تجارب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نصائح').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون تخصص'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicine').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'نشر'));
      await tester.pumpAndSettle();
      expect(bodies.single, {
        'title': 'نصيحة',
        'body': 'ابدأ مبكرًا',
        'topic': 'tips',
        'studyField': 'med'
      });
      expect(find.text('تجاوزت الحد المسموح مؤقتًا. حاول بعد قليل.'),
          findsOneWidget);
      expect(find.text('نصيحة'), findsOneWidget);
      expect(find.byType(CommunityComposeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
              return reply({'message': 'Too many requests'}, 429);
            }));
  });

  testWidgets(
      'thread: report needs a reason and confirmation; own comment can be deleted',
      (tester) async {
    phone(tester);
    final calls = <String>[];
    var deleted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: CommunityThreadScreen(postId: 'p1')));
      await tester.pumpAndSettle();
      expect(find.text('أين أجد سكنًا مناسبًا؟'), findsOneWidget);
      // Someone else's post can be reported, not deleted.
      expect(find.text('حذف موضوعي'), findsNothing);

      await tester.tap(find.text('إبلاغ').first);
      await tester.pumpAndSettle();
      FilledButton send() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'إرسال البلاغ'));
      expect(send().onPressed, isNull);
      await tester.tap(find.text('إعلان أو محتوى متكرر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إرسال البلاغ'));
      await tester.pumpAndSettle();
      expect(calls, [
        'POST /api/community/posts/p1/report {"reason":"spam","details":""}'
      ]);
      expect(find.text('سبق أن أبلغت عن هذا المحتوى.'), findsOneWidget);

      // Own comment: delete (after confirmation), no report button.
      expect(find.text('حذف تعليقي'), findsOneWidget);
      await tester.tap(find.text('حذف تعليقي'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      await tester.tap(find.text('حذف').last);
      await tester.pumpAndSettle();
      expect(calls.last, 'DELETE /api/community/comments/c1 ');
      expect(find.text('حذف تعليقي'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              if (r.method == 'GET') {
                return reply({
                  'post': publicPost,
                  'comments': deleted
                      ? []
                      : [
                          {'_id': 'c1', 'body': 'تعليقي', 'author': me}
                        ],
                });
              }
              calls.add('${r.method} ${r.url.path} ${r.body}');
              if (r.method == 'DELETE') {
                deleted = true;
                return reply({'message': 'Comment deleted'});
              }
              return reply(
                  {'message': 'You already reported this content'}, 409);
            }));
  });
}
