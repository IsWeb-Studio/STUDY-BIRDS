import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/applications_documents_payments/program_application_screen.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/profile_account/passport_scanner_screen.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  setUp(() {
    AuthSession.instance.token = 'test-token';
    ApiClient.instance.clearCache();
  });
  tearDown(() => AuthSession.instance.token = null);
  for (final program in [true, false]) {
    testWidgets(
        '${program ? 'program application' : 'my documents'} offers camera, photos and files for passport',
        (tester) async {
      await http.runWithClient(() async {
        await mount(
            tester,
            program
                ? const ProgramApplicationScreen(programId: 'p')
                : const MyDocumentsScreen());
        if (program) {
          final upload = find.text('تصوير أو رفع مستند');
          await tester.scrollUntilVisible(upload, 300,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(upload);
        } else {
          await tester.tap(find.byTooltip('رفع مستند'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('جواز السفر'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);
        expect(find.text('اختيار من الصور'), findsOneWidget);
        expect(find.text('اختيار ملف PDF أو صورة'), findsOneWidget);
        // Taking a photo follows the live scanner route, never the file picker.
        await tester.tap(find.text('التقاط صورة بالكاميرا'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PassportScannerScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('إلغاء'));
        await tester.pumpAndSettle();
      },
          () => MockClient((request) async {
                final Object data = switch (request.url.path) {
                  '/api/programs/p' => {
                      '_id': 'p',
                      'title': 'Test',
                      'requiredDocumentTypes': ['passport']
                    },
                  '/api/students/profile' => {
                      'user': {
                        'name': 'Student',
                        'email': 'student@example.test'
                      },
                      'phone': '+905551234567'
                    },
                  '/api/students/documents' => <Object>[],
                  _ => <String, Object>{},
                };
                return http.Response(jsonEncode(data), 200, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
    });
  }
}
