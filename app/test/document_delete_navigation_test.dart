import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/visa_travel_accommodation/arrival_services_screen.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  setUp(() {
    AuthSession.instance.token = 'delete-navigation';
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });

  testWidgets('long press requires confirmation and removes only after success',
      (tester) async {
    var archived = false;
    await http.runWithClient(() async {
      await mount(tester, const MyDocumentsScreen());
      await tester.longPress(find.text('transcript.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(archived, false);
      expect(find.text('transcript.pdf'), findsOneWidget);
      await tester.drag(find.text('transcript.pdf'), const Offset(600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(archived, true);
      expect(find.text('transcript.pdf'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH') archived = true;
              return http.Response(
                  jsonEncode(request.method == 'PATCH'
                      ? {}
                      : [
                          {
                            '_id': 'deletable',
                            'type': 'transcript',
                            'fileName': 'transcript.pdf',
                            'uploadStatus': 'uploaded',
                            if (archived) 'archivedAt': '2026-10-15'
                          }
                        ]),
                  200);
            }));
  });

  testWidgets('rapid new trip taps open one picker while applications load',
      (tester) async {
    var calls = 0;
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await mount(tester, const ArrivalServicesScreen());
      final action = tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed!;
      action();
      action();
      action();
      await tester.pump();
      expect(calls, 1);
      response.complete(http.Response('[]', 200));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/applications')) {
                calls++;
                return response.future;
              }
              return http.Response('[]', 200);
            }));
  });
}
