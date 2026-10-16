import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';

void main() {
  setUp(() {
    AuthSession.instance.token = 'chat-controls';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'me', name: 'Me', email: 'me@test.example', role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets(
      'wide chat is full screen with personal mute, hide, and unsend controls',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var muted = false;
    final deleted = <String>[];
    final messages = <Map<String, dynamic>>[
      {
        '_id': '1',
        'sender': 'peer',
        'body': 'received message',
        'createdAt': '2026-10-16T09:00:00Z'
      },
      {
        '_id': '2',
        'sender': 'me',
        'body': 'my message',
        'createdAt': '2026-10-16T09:01:00Z'
      },
    ];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: ConversationThreadScreen(
              contactId: 'peer', contactName: 'Sara')));
      await tester.pumpAndSettle();
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('تواصل مع فريقك'), findsNothing);
      expect(find.text('لا توجد جهات اتصال متاحة حاليًا.'), findsNothing);
      expect(find.byTooltip('إرفاق صورة'), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).width, greaterThan(900));

      await tester.tap(find.byTooltip('خيارات المحادثة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('كتم الإشعارات'));
      await tester.pumpAndSettle();
      expect(muted, isTrue);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

      await tester.longPress(find.text('my message'));
      await tester.pumpAndSettle();
      expect(find.text('نسخ النص'), findsOneWidget);
      await tester.tap(find.text('إلغاء الإرسال للجميع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(deleted, contains('2:everyone'));
      expect(find.text('my message'), findsNothing);
      expect(find.text('تم حذف هذه الرسالة'), findsOneWidget);

      await tester.longPress(find.text('received message'));
      await tester.pumpAndSettle();
      expect(find.text('إلغاء الإرسال للجميع'), findsNothing);
      await tester.tap(find.text('حذف لدي'));
      await tester.pumpAndSettle();
      expect(deleted, contains('1:me'));
      expect(find.text('received message'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              Object data = {};
              if (path.endsWith('/conversations/peer')) {
                if (request.method == 'PUT')
                  muted = jsonDecode(request.body)['muted'] == true;
                data = {'muted': muted};
              }
              if (path.endsWith('/messages')) data = messages;
              if (request.method == 'DELETE' && path.contains('/messages/')) {
                final id = path.split('/').last;
                final scope = request.url.queryParameters['scope'];
                deleted.add('$id:$scope');
                if (scope == 'me') {
                  messages.removeWhere((m) => m['_id'] == id);
                } else {
                  messages.firstWhere((m) => m['_id'] == id).addAll(
                      {'body': '', 'deletedAt': '2026-10-16T10:00:00Z'});
                }
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets('remote unsend updates the visible bubble without reopening',
      (tester) async {
    var removed = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: ConversationThreadScreen(
              contactId: 'peer', contactName: 'Sara')));
      await tester.pumpAndSettle();
      expect(find.text('old content'), findsOneWidget);
      removed = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('old content'), findsNothing);
      expect(find.text('تم حذف هذه الرسالة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final Object data = request.url.path.endsWith('/messages')
                  ? [
                      {
                        '_id': '1',
                        'sender': 'peer',
                        'body': removed ? '' : 'old content',
                        'createdAt': '2026-10-16T09:00:00Z',
                        if (removed) 'deletedAt': '2026-10-16T10:00:00Z'
                      },
                    ]
                  : {};
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
