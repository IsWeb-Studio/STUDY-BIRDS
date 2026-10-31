import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/agent_student_detail_screen.dart';
import 'package:study_birds/screens/roles/admin_approval_screens.dart';

void main() {
  setUp(() => AuthSession.instance.token = 'wallet-controls');
  tearDown(() => AuthSession.instance.token = null);
  testWidgets('agent can request a commission review from the wallet', (tester) async {
    var sent = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyCommissionsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('محجوز لطلبات السحب: \$40'), findsOneWidget);
      await tester.ensureVisible(find.text('طلب مراجعة رصيد أو عمولة'));
      await tester.tap(find.text('طلب مراجعة رصيد أو عمولة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Review student commission 100 USD');
      await tester.tap(find.text('إرسال للمراجعة'));
      await tester.pumpAndSettle();
      expect(sent, isTrue);
      expect(find.text('تم إنشاء تذكرة مراجعة. تابع الرد في تذاكر الدعم.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, endsWith('/partners/tickets'));
        expect(jsonDecode(request.body)['category'], 'commission'); sent = true;
        return http.Response('{"_id":"ticket"}', 201);
      }
      return http.Response('{"summary":{"availableBalance":100,"reservedBalance":40},"entries":[],"payouts":[]}', 200);
    }));
  });
  testWidgets('admin payout section exposes the agent adjustment ledger', (tester) async {
    var loaded = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminPayoutRequestsScreen()));
      await tester.tap(find.text('إضافة أو تسوية رصيد وكيل'));
      await tester.pumpAndSettle();
      expect(loaded, isTrue);
      expect(find.text('Agent balances'), findsOneWidget);
      expect(find.text('Agent ID'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
      expect(request.url.path, endsWith('/admin/payout-requests/wallet-entries')); loaded = true;
      return http.Response('[]', 200);
    }));
  });
}
