import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/roles/admin_app_notification_screen.dart';

void main() {
  const audience = <String, dynamic>{
    'activeUsers': 42,
    'pushEligibleUsers': 31,
    'pushConfigured': true,
    'canBroadcast': true,
  };

  testWidgets('admin can send a confirmed announcement to the shown audience',
      (tester) async {
    var sends = 0;
    String? submittedTitle;
    String? submittedMessage;
    String? submittedKey;

    await tester.pumpWidget(MaterialApp(
      home: AdminAppNotificationScreen(
        loadAudience: () async => audience,
        sendBroadcast: ({
          required title,
          required message,
          required idempotencyKey,
        }) async {
          sends++;
          submittedTitle = title;
          submittedMessage = message;
          submittedKey = idempotencyKey;
          return const {
            'recipientCount': 42,
            'pushEligibleCount': 31,
            'pushConfigured': true,
            'pushReportedRecipientCount': 29,
            'pushUnconfirmedBatches': 0,
          };
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('الحسابات النشطة: 42'), findsOneWidget);
    expect(find.text('المؤهلون للتنبيه الفوري: 31'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('app-notification-title')), 'منحة جديدة');
    await tester.enterText(
        find.byKey(const ValueKey('app-notification-message')),
        'بدأ التقديم اليوم.');
    await tester.pump();

    await tester
        .ensureVisible(find.byKey(const ValueKey('send-app-notification')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
              find.byKey(const ValueKey('send-app-notification')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('send-app-notification')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
        find.textContaining('سيُحفظ الإشعار في صندوق الوارد'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('إرسال للجميع'),
    ));
    await tester.pumpAndSettle();

    expect(sends, 1);
    expect(submittedTitle, 'منحة جديدة');
    expect(submittedMessage, 'بدأ التقديم اليوم.');
    expect(submittedKey, isNotEmpty);
    expect(find.byKey(const ValueKey('app-notification-send-result')),
        findsOneWidget);
    expect(find.textContaining('تم حفظ الإشعار في 42 حسابًا نشطًا'),
        findsOneWidget);
  });

  testWidgets('broadcast remains disabled when the account cannot broadcast',
      (tester) async {
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
      home: AdminAppNotificationScreen(
        loadAudience: () async => const {
          'activeUsers': 42,
          'pushEligibleUsers': 31,
          'pushConfigured': true,
          'canBroadcast': false,
        },
        sendBroadcast: (
            {required title, required message, required idempotencyKey}) async {
          sends++;
          return const {};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('app-notification-title')), 'منحة جديدة');
    await tester.enterText(
        find.byKey(const ValueKey('app-notification-message')),
        'تفاصيل المنحة');
    await tester.pump();

    final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('send-app-notification')));
    expect(button.onPressed, isNull);
    expect(find.text('إرسال الإعلانات متاح لحساب الأدمن فقط.'), findsOneWidget);
    expect(sends, 0);
  });
}
