import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/admin_financials_marketing_screens.dart';
import 'package:study_birds/screens/roles/admin_partner_profile_screen.dart';
import 'package:study_birds/screens/roles/agent_student_detail_screen.dart';

http.Response jsonReply(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() {
    AuthSession.instance.token = 'parity-test-token';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'partner-1',
      name: 'Partner',
      email: 'partner@example.test',
      role: UserRole.agent,
    );
  });

  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets('admin can edit and publish a marketing asset in the app',
      (tester) async {
    final calls = <http.Request>[];
    var saved = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminMarketingAssetsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Updated partner flyer');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final update = calls.singleWhere((request) => request.method == 'PUT');
      final payload = jsonDecode(update.body) as Map<String, dynamic>;
      expect(payload['title'], 'Updated partner flyer');
      expect(payload['published'], false);
      expect(find.text('Updated partner flyer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
          calls.add(request);
          if (request.method == 'GET' && request.url.path.endsWith('/admin/marketing-assets')) {
            return jsonReply([
              {
                '_id': 'asset-1',
                'title': saved ? 'Updated partner flyer' : 'Partner flyer',
                'description': 'Current flyer',
                'type': 'pdf',
                'published': !saved,
                'fileName': 'flyer.pdf',
              }
            ]);
          }
          if (request.method == 'PUT' && request.url.path.endsWith('/admin/marketing-assets/asset-1')) {
            saved = true;
            return jsonReply({
              '_id': 'asset-1',
              'title': 'Updated partner flyer',
              'description': 'Current flyer',
              'type': 'pdf',
              'published': false,
              'fileName': 'flyer.pdf',
            });
          }
          return jsonReply({}, 404);
        }));
  });

  testWidgets('partner payout form sends selected amount and payment details',
      (tester) async {
    final requests = <(String method, Map<String, dynamic> body)>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyCommissionsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('طلب سحب الرصيد المتاح'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '25');
      await tester.enterText(fields.at(1), 'Account ending 1234');
      await tester.tap(find.text('إرسال الطلب'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.$1, 'POST');
      expect(requests.single.$2['amount'], 25.0);
      expect(requests.single.$2['method'], 'bank-account');
      expect(requests.single.$2['payoutDetails'], 'Account ending 1234');
      expect(find.text('تم إرسال طلب السحب.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
          if (request.url.path.endsWith('/partners/wallet') && request.method == 'GET') {
            return jsonReply({
              'summary': {'availableBalance': 50, 'pendingBalance': 0, 'receivedBalance': 0},
              'entries': [],
              'payouts': [],
            });
          }
          if (request.url.path.endsWith('/partners/wallet/payout-requests') && request.method == 'POST') {
            requests.add((request.method, jsonDecode(request.body) as Map<String, dynamic>));
            return jsonReply({'_id': 'payout-1', 'amount': 25, 'method': 'bank-account', 'status': 'pending'}, 201);
          }
          return jsonReply({}, 404);
        }));
  });

  testWidgets('partner can edit a linked student record from its details',
      (tester) async {
    final updates = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: AgentStudentDetailScreen(
          studentId: 'student-1',
          initialData: {
            '_id': 'student-1',
            'name': 'Student One',
            'email': 'student@example.test',
            'phone': '+1000000000',
            'documents': [],
          },
        ),
      ));
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Updated Student');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(updates, hasLength(1));
      expect(updates.single['name'], 'Updated Student');
      expect(find.text('Updated Student'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
          if (request.method == 'PUT' && request.url.path.endsWith('/partners/students/student-1')) {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            updates.add(payload);
            return jsonReply({'_id': 'student-1', ...payload, 'documents': []});
          }
          return jsonReply({}, 404);
        }));
  });

  testWidgets('admin can change a partner account status from its profile',
      (tester) async {
    AuthSession.instance.currentUser = const AuthUser(
      id: 'admin-1',
      name: 'Admin',
      email: 'admin@example.test',
      role: UserRole.admin,
    );
    final calls = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: AdminPartnerProfileScreen(partnerId: 'partner-2'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      final update = calls.singleWhere((request) => request.method == 'PATCH');
      expect(update.url.path, endsWith('/admin/partners/partner-2/status'));
      expect(jsonDecode(update.body), {'isActive': false});
      expect(find.text('الحساب معطل'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
          calls.add(request);
          if (request.method == 'GET' && request.url.path.endsWith('/admin/partners/partner-2')) {
            return jsonReply({
              'partner': {
                '_id': 'partner-2',
                'name': 'Partner Two',
                'email': 'partner2@example.test',
                'isActive': true,
                'profile': {'companyName': 'Agency Two', 'location': 'Amman'},
              },
              'students': [],
              'payoutRequests': [],
              'supportTickets': [],
              'verificationDocuments': [],
              'walletEntries': [],
              'notifications': [],
            });
          }
          if (request.method == 'PATCH' && request.url.path.endsWith('/admin/partners/partner-2/status')) {
            return jsonReply({'isActive': false});
          }
          return jsonReply({}, 404);
        }));
  });
}
