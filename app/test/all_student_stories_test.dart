import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/stories/all_student_stories.dart';

void main() {
  setUp(() => AuthSession.instance.token = 'all-stories');
  tearDown(() => AuthSession.instance.token = null);
  testWidgets(
      'community view all opens the published stories page and loads later pages',
      (tester) async {
    Map<String, dynamic> story(String id, String text) => {
          'id': id,
          'text': text,
          'author': {'id': 'author-$id', 'name': 'Student $id'},
          'expiresAt':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String()
        };
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentCommunityHub()));
      await tester.pumpAndSettle();
      expect(find.text('الستوريات المنشورة'), findsOneWidget);
      await tester.tap(find.text('عرض الكل'));
      await tester.pumpAndSettle();
      expect(find.byType(AllStudentStoriesScreen), findsOneWidget);
      expect(find.text('First community story'), findsOneWidget);
      await tester.ensureVisible(find.text('تحميل المزيد'));
      await tester.tap(find.text('تحميل المزيد'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Later community story'));
      expect(find.text('Later community story'), findsOneWidget);
      expect(find.text('تحميل المزيد'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              Object data = {};
              if (request.url.path.endsWith('/stories'))
                data = request.url.queryParameters['before'] == null
                    ? {
                        'stories': [story('1', 'First community story')],
                        'nextCursor': 'page2'
                      }
                    : {
                        'stories': [story('2', 'Later community story')],
                        'nextCursor': null
                      };
              if (request.url.path.endsWith('/conversations'))
                data = {'conversations': [], 'unreadTotal': 0};
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets(
      'an empty published feed explains that no stories are currently available',
      (tester) async {
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: AllStudentStoriesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد ستوريات منشورة حاليًا'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => http.Response('{"stories":[]}', 200)));
  });
}
