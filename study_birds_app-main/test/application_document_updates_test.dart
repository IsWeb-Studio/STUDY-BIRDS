import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  for (final scenario in [0, 1, 2]) {
    final conflict = scenario == 1;
    final additional = scenario == 2;
    testWidgets(
        'replace document confirms before submission; conflict=$conflict additional=$additional',
        (tester) async {
      AuthSession.instance.token = 'test';
      AuthSession.instance.currentUser = AuthUser.fromJson({
        '_id': 'student',
        'name': 'Student',
        'email': 'student@example.test',
        'role': 'student'
      });
      addTearDown(() {
        AuthSession.instance.token = null;
        AuthSession.instance.currentUser = null;
      });
      final old = {
        '_id': 'old',
        'type': additional ? 'language-certificate' : 'transcript',
        'fileName': 'old.pdf',
        'status': additional ? 'verified' : 'rejected'
      };
      final replacement = {
        '_id': 'new',
        'type': additional ? 'language-certificate' : 'transcript',
        'fileName': 'new.pdf',
        'status': 'pending'
      };
      final application = <String, dynamic>{
        '_id': 'a',
        '__v': 3,
        'status': 'submitted',
        'detailedStatus': 'documents-missing',
        'requiredDocumentTypes': additional ? <String>[] : ['transcript'],
        if (additional)
          'documentRequests': [
            {
              '_id': 'request',
              'type': 'language-certificate',
              'status': 'requested',
              'note': 'نسخة حديثة من شهادة اللغة'
            }
          ],
        'documents': [old]
      };
      Map<String, dynamic>? submitted;
      await http.runWithClient(() async {
        await mount(tester, ApplicationDetailScreen(application: application));
        await tester.tap(find.byTooltip('استكمال مستندات الطلب'));
        await tester.pumpAndSettle();
        if (additional)
          expect(
              find.textContaining('نسخة حديثة من شهادة اللغة'), findsOneWidget);
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('new.pdf').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('إرفاق بالطلب'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('رجوع'));
        await tester.pumpAndSettle();
        expect(submitted, isNull);
        await tester.tap(find.text('إرفاق بالطلب'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إرفاق'));
        await tester.pumpAndSettle();
        expect(submitted, {'documentId': 'new', 'version': 3});
        if (conflict) {
          expect(find.textContaining('تغير الطلب'), findsOneWidget);
          expect(find.text('تحديث البيانات'), findsOneWidget);
        } else {
          expect(find.text('تفاصيل الطلب'), findsOneWidget);
          await tester.tap(find.text('المستندات'));
          await tester.pumpAndSettle();
          expect(find.text('مرفوض'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                Object response;
                if (request.method == 'PATCH') {
                  submitted = jsonDecode(request.body) as Map<String, dynamic>;
                  if (conflict)
                    return http.Response(
                        jsonEncode({'message': 'Conflict'}), 409);
                  response = {
                    ...application,
                    '__v': 4,
                    'documents': [replacement]
                  };
                } else if (request.url.path.endsWith('/students/documents')) {
                  response = [old, replacement];
                } else {
                  response = application;
                }
                return http.Response(jsonEncode(response), 200, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
    });
  }
}
