import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/repositories/student_repository.dart';
import 'package:study_birds/screens/applications_documents_payments/program_application_screen.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  setUp(() => AuthSession.instance.token = 'test-token');
  tearDown(() => AuthSession.instance.token = null);

  test('overview accepts older API and new next-action data', () {
    expect(DashboardOverview.fromJson({}).nextAction, isNull);
    expect(
        DashboardOverview.fromJson({
          'nextAction': {'destination': 'payments', 'waiting': true}
        }).nextAction?['waiting'],
        true);
  });

  for (final hasDocument in [false, true]) {
    testWidgets('custom document requirement, available=$hasDocument',
        (tester) async {
      Map<String, dynamic>? submitted;
      await http.runWithClient(() async {
        await mount(
            tester, const ProgramApplicationScreen(programId: 'program'));
        expect(tester.takeException(), isNull);
        final button = find.text('مراجعة وإرسال الطلب');
        await tester.scrollUntilVisible(button, 400,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(button);
        await tester.pumpAndSettle();
        if (!hasDocument) {
          expect(find.text('أكمل المستندات المطلوبة قبل إرسال الطلب.'),
              findsOneWidget);
          expect(submitted, isNull);
        } else {
          expect(find.text('إرسال طلب التقديم؟'), findsOneWidget);
          await tester.tap(find.text('مراجعة'));
          await tester.pumpAndSettle();
          expect(submitted, isNull);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.tap(find.text('إرسال الطلب'));
          await tester.pumpAndSettle();
          expect(submitted?['documentIds'], ['transcript-file']);
          expect(submitted?['programId'], 'program');
          expect(find.byType(ApplicationDetailScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
          () => MockClient((request) async {
                Object data;
                switch (request.url.path) {
                  case '/api/programs/program':
                    data = {
                      '_id': 'program',
                      'title': 'برنامج تجريبي',
                      'requiredDocumentTypes': ['transcript']
                    };
                  case '/api/students/profile':
                    data = {
                      'user': {
                        'name': 'Student',
                        'email': 'student@example.test'
                      },
                      'phone': '+905551234567'
                    };
                  case '/api/students/documents':
                    data = hasDocument
                        ? [
                            {
                              '_id': 'transcript-file',
                              'type': 'transcript',
                              'fileName': 'grades.pdf',
                              'status': 'verified'
                            }
                          ]
                        : [];
                  case '/api/applications':
                    submitted =
                        jsonDecode(request.body) as Map<String, dynamic>;
                    data = {
                      '_id': 'created',
                      'status': 'submitted',
                      'documents': [],
                      'statusTimeline': []
                    };
                  default:
                    throw StateError('Unexpected request: ${request.url}');
                }
                return http.Response(jsonEncode(data), 200, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
    });
  }
}
