import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/profile_account/edit_profile_screen.dart';
import 'package:study_birds/screens/profile_account/passport_scanner_screen.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  for (final uploaded in [false, true]) {
    testWidgets(
        'passport ${uploaded ? 'shows saved identity' : 'offers upload'} without manual inputs',
        (tester) async {
      AuthSession.instance.token = 'passport-test';
      ApiClient.instance.clearCache();
      try {
        await http.runWithClient(() async {
          await mount(tester,
              const EditProfileScreen(section: ProfileSection.passport));
          expect(find.byType(TextFormField), findsNothing);
          expect(find.text('حفظ البيانات'), findsNothing);
          if (uploaded) {
            expect(find.text('FIRST PERSON'), findsOneWidget);
            expect(find.text('ABC123'), findsOneWidget);
            expect(find.text('1990-01-02'), findsOneWidget);
          } else {
            expect(find.text('بيانات صاحب الجواز'), findsNothing);
            final upload = find.byType(OutlinedButton).last;
            await tester.ensureVisible(upload);
            await tester.tap(upload);
            await tester.pumpAndSettle();
            await tester.tap(find.text('التقاط صورة بالكاميرا'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(
                tester
                    .widget<PassportScannerScreen>(
                        find.byType(PassportScannerScreen))
                    .allowEditing,
                false);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
            () => MockClient((request) async => http.Response(
                jsonEncode(request.url.path.endsWith('/documents')
                    ? <Object>[]
                    : {
                        if (uploaded)
                          'passportIdentity': {
                            'number': 'ABC123',
                            'name': 'FIRST PERSON',
                            'birth': '1990-01-02',
                            'expiry': '2035-01-02',
                            'nationality': 'UTO',
                            'sex': 'F',
                          },
                      }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'})));
      } finally {
        AuthSession.instance.token = null;
      }
    });
  }
}
