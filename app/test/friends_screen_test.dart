import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/friends_screen.dart';

http.Response page(List<Map<String, dynamic>> people,
        {Map<String, int>? counts}) =>
    http.Response(
        jsonEncode({
          'people': people,
          'nextCursor': null,
          if (counts != null) 'counts': counts
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> person(String name, String relation) => {
      'id': 'student-id',
      'name': name,
      'avatar': '',
      'total_points': 0,
      'relation': relation
    };
void main() {
  testWidgets(
      'search, request, cancel and accept update the right friend lists without duplicate actions',
      (tester) async {
    AuthSession.instance.token = 'friends-ui-test';
    addTearDown(() => AuthSession.instance.token = null);
    var relation = 'none', incoming = true;
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: FriendsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('أضف أصدقاء لتشوف يومياتهم هنا'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Student');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Student'), findsNWidgets(2)); // Search and result.
      final add = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'إضافة'))
          .onPressed!;
      add();
      add();
      add();
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('إلغاء الطلب'), findsOneWidget);
      await tester.tap(find.text('إلغاء الطلب'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة'), findsOneWidget);
      await tester.tap(find.textContaining('طلبات واردة'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming Student'), findsOneWidget);
      await tester.tap(find.text('قبول'));
      await tester.pumpAndSettle();
      expect(incoming, false);
      await tester.tap(find.textContaining('أصدقائي'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming Student'), findsOneWidget);
      expect(find.byTooltip('إزالة الصديق'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'POST' &&
                  request.url.path.endsWith('/request')) {
                relation = 'outgoing';
                requests++;
                return http.Response('{}', 200);
              }
              if (request.method == 'POST' &&
                  request.url.path.endsWith('/accept')) {
                incoming = false;
                relation = 'friends';
                return http.Response('{}', 200);
              }
              if (request.method == 'DELETE') {
                relation = 'none';
                return http.Response('{}', 200);
              }
              if (request.url.path.endsWith('/search')) {
                return page([person('Student', relation)]);
              }
              final kind = request.url.queryParameters['kind'];
              return page(
                  kind == 'incoming' && incoming
                      ? [person('Incoming Student', 'incoming')]
                      : kind == 'friends' && relation == 'friends'
                          ? [person('Incoming Student', 'friends')]
                          : [],
                  counts: {
                    'friends': relation == 'friends' ? 1 : 0,
                    'incoming': incoming ? 1 : 0,
                    'outgoing': relation == 'outgoing' ? 1 : 0
                  });
            }));
  });
  testWidgets('late search results cannot replace a newer query',
      (tester) async {
    AuthSession.instance.token = 'friends-search-test';
    addTearDown(() => AuthSession.instance.token = null);
    final old = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: FriendsScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Bobby');
      old.complete(page([person('Old Alice', 'none')]));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Old Alice'), findsNothing);
      expect(find.text('New Bobby'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient(
            (request) async => request.url.queryParameters['q'] == 'Alice'
                ? await old.future
                : request.url.queryParameters['q'] == 'Bobby'
                    ? page([person('New Bobby', 'none')])
                    : page([])));
  });
}
