import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/currency_service.dart';
import 'package:study_birds/screens/applications_documents_payments/payments_screens.dart';
import 'package:study_birds/screens/home_journey/notifications_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'first-invoice-widget';
  });
  tearDown(() => AuthSession.instance.token = null);
  testWidgets('an invoice outside application groups remains visible', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: PaymentsSummaryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('First invoice'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
      if (request.url.host == 'api.frankfurter.dev') {
        return http.Response(jsonEncode(supportedCurrencies.keys.where((c) => c != 'USD').map((c) => {'base': 'USD', 'quote': c, 'rate': 1}).toList()), 200);
      }
      return http.Response(jsonEncode({
        'summary': {}, 'applicationGroups': [{'programTitle': 'Program', 'invoices': []}],
        'invoices': [{'_id': 'first', 'description': 'First invoice', 'amount': 100, 'status': 'unpaid'}],
      }), 200);
    }));
  });
  testWidgets('old missing invoice notification has a clear current invoices action', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: notificationScreenForLink('/student/payments/deleted')!));
      await tester.pumpAndSettle();
      expect(find.text('عرض الفواتير الحالية'), findsOneWidget);
      expect(find.byType(PaymentsSummaryScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => http.Response('{"invoices":[]}', 200)));
  });
  testWidgets('temporary invoice error can be retried without redirecting', (tester) async {
    var attempts = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: notificationScreenForLink('/student/payments/first')!));
      await tester.pumpAndSettle();
      expect(find.text('تعذر الاتصال لتحميل الفاتورة. أعد المحاولة.'), findsOneWidget);
      expect(attempts, 1);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async { attempts++; return http.Response('{"message":"Unavailable"}', 503); }));
  });
}
