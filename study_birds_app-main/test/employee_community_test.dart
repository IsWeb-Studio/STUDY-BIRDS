import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/employee_community_screen.dart';

http.Response reply(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

const author = {'_id': 'u1', 'name': 'Omar', 'email': 'omar@example.test'};
const detail = {
  'post': {
    '_id': 'p1',
    'title': 'إعلان سكن',
    'body': 'تواصلوا معي',
    'status': 'published',
    'author': author,
  },
  'comments': [
    {
      '_id': 'c1',
      'body': 'تعليق مخفي',
      'status': 'hidden',
      'moderationNote': 'إساءة',
      'author': {'_id': 'u2', 'name': 'Sami'},
    }
  ],
  'reports': [
    {
      '_id': 'r1',
      'targetType': 'post',
      'target': 'p1',
      'reason': 'spam',
      'status': 'open',
      'reporter': {'name': 'Lina'},
    }
  ],
  'log': [],
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    AuthSession.instance.token = 'staff-session';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'staff',
        name: 'Moderator',
        email: 'mod@example.test',
        role: UserRole.employee,
        permissions: {'community'});
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets('open reports lead to the post; suspended students can be lifted',
      (tester) async {
    phone(tester);
    final calls = <String>[];
    var lifted = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: EmployeeCommunityScreen()));
      await tester.pumpAndSettle();
      expect(find.text('البلاغات المفتوحة (1)'), findsOneWidget);
      expect(find.text('إعلان سكن'), findsOneWidget);
      expect(find.textContaining('إعلان أو محتوى متكرر'), findsOneWidget);

      await tester.tap(find.text('الموقوفون (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('حتى رفعه يدويًا'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'رفع الإيقاف'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      // The confirmation dialog's own button.
      await tester.tap(find.text('رفع الإيقاف').last);
      await tester.pumpAndSettle();
      expect(calls, ['DELETE /api/admin/community-suspensions/u1']);
      expect(find.text('الموقوفون (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              expect(r.headers['authorization'], 'Bearer staff-session');
              if (r.method == 'DELETE') {
                calls.add('DELETE ${r.url.path}');
                lifted = true;
                return reply({'message': 'Suspension lifted'});
              }
              if (r.url.path.endsWith('/community-reports')) {
                expect(r.url.query, 'status=open');
                return reply([
                  {
                    '_id': 'r1',
                    'targetType': 'post',
                    'reason': 'spam',
                    'post': {'_id': 'p1', 'title': 'إعلان سكن'},
                    'reporter': {'name': 'Lina'},
                  }
                ]);
              }
              return reply(lifted
                  ? []
                  : [
                      {
                        '_id': 's1',
                        'user': author,
                        'until': null,
                        'reason': 'إساءة متكررة',
                      }
                    ]);
            }));
  });

  testWidgets(
      'hiding needs a reason, suspending sends the duration, conflicts explained',
      (tester) async {
    phone(tester);
    final writes = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: EmployeeCommunityPostScreen(postId: 'p1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 بلاغ مفتوح'), findsOneWidget);
      // The hidden comment is visible to the moderator with its note.
      expect(find.textContaining('مخفي · إساءة'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'إخفاء'));
      await tester.pumpAndSettle();
      FilledButton confirm() => tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'إخفاء'));
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'إعلان تجاري');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'إخفاء'));
      await tester.pumpAndSettle();
      expect(writes.first,
          'PATCH /api/admin/community-posts/p1 {"status":"hidden","moderationNote":"إعلان تجاري"}');
      expect(
          find.text(
              'عدّل مشرف آخر هذا المحتوى للتو. حدّث الصفحة وحاول مجددًا.'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'إيقاف الكاتب').first);
      await tester.pumpAndSettle();
      expect(find.text('إيقاف Omar عن النشر'), findsOneWidget);
      await tester.tap(find.text('أسبوع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شهر').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'السبب'), 'مخالفات متكررة');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'إيقاف'));
      await tester.pumpAndSettle();
      expect(writes.last,
          'POST /api/admin/community-suspensions {"user":"u1","reason":"مخالفات متكررة","days":30}');
      expect(find.text('تم إيقاف Omar عن النشر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              if (r.method == 'GET') return reply(detail);
              writes.add('${r.method} ${r.url.path} ${r.body}');
              if (r.method == 'PATCH') {
                return reply({'message': 'moderated by someone else'}, 409);
              }
              return reply({'_id': 's1'}, 201);
            }));
  });
}
