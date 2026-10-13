import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/status_info.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';

Map<String, dynamic> info(String status, String tone, String label,
        String meaning, String next) =>
    {
      'status': status,
      'code': 'X',
      'tone': tone,
      'ar': {'label': label, 'meaning': meaning, 'nextStep': next},
      'en': {'label': label, 'meaning': meaning, 'nextStep': next},
    };

final rejectedPassport = {
  '_id': 'd1',
  'type': 'passport',
  'fileName': 'passport.pdf',
  'status': 'rejected',
  'detailedStatus': 'rejected',
  'reviewNote': 'الختم غير واضح',
  'expiresAt': '2030-05-01T00:00:00Z',
  'createdAt': '2026-09-01T10:00:00Z',
  'statusInfo': info(
      'rejected',
      'danger',
      'مرفوض',
      'تم رفض المستند نظرًا لـ: الختم غير واضح',
      'يرجى إعادة رفع المستند بعد معالجة السبب.'),
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('server copy wins; codes without copy still get a correct Arabic label',
      () {
    final meta = appStatusMeta({
      'detailedStatus': 'payment-verification',
      'statusInfo': info('payment-verification', 'info', 'التحقق من الدفع',
          'استلمنا إثبات الدفع', 'لا مطلوب منك شيء'),
    });
    expect(meta.label, 'التحقق من الدفع');
    // Timeline entries carry only a code — including website review actions.
    expect(
        appStatusMeta({'status': 'preliminary-accepted'}).label, 'قبول مبدئي');
    expect(appStatusMeta({'status': 'final-accepted'}).label, 'قبول نهائي');
    expect(appStatusMeta({'status': 'file-completed-rejected'}).label,
        'غير مقبول');
    // "Completed" is not the same as "accepted".
    expect(appStatusMeta({'detailedStatus': 'completed'}).label, 'مكتمل');
    expect(StatusInfo.of({'statusInfo': 'broken'}), isNull);
    expect(docStatusMeta(rejectedPassport).label, 'مرفوض');
  });

  testWidgets(
      'document detail explains the rejection reason, next step and validity',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(
        MaterialApp(home: DocumentDetailScreen(document: rejectedPassport)));
    await tester.pumpAndSettle();
    expect(
        find.text('تم رفض المستند نظرًا لـ: الختم غير واضح'), findsOneWidget);
    expect(find.textContaining('يرجى إعادة رفع المستند'), findsOneWidget);
    expect(find.text('صالح حتى'), findsOneWidget);
    // The raw note is not shown twice when the explanation already carries it.
    expect(find.text('الختم غير واضح'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('documents list shows what to fix without opening the document',
      (tester) async {
    phone(tester);
    AuthSession.instance.token = 'test';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyDocumentsScreen()));
      await tester.pumpAndSettle();
      expect(
          find.text('تم رفض المستند نظرًا لـ: الختم غير واضح'), findsOneWidget);
      // An approved document needs no extra line.
      expect(find.text('تمت مراجعة المستند واعتماده.'), findsNothing);
      expect(find.text('معتمد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => http.Response(
            jsonEncode([
              rejectedPassport,
              {
                '_id': 'd2',
                'type': 'transcript',
                'fileName': 't.pdf',
                'status': 'verified',
                'statusInfo': info('approved', 'success', 'معتمد',
                    'تمت مراجعة المستند واعتماده.', 'لا حاجة لأي إجراء.'),
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
