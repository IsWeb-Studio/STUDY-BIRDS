import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/screens/services_support/public_student_content.dart';

void main() {
  tearDown(() => ApiClient.instance.clearCache());
  testWidgets('success stories show published names and quotes',
      (tester) async {
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: PublicStudentContentScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Published student'), findsOneWidget);
      expect(find.text('My university experience'), findsOneWidget);
      expect(find.text('Canada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(
                  request.url.path.endsWith('/content/testimonials'), isTrue);
              return http.Response(
                  jsonEncode({
                    'items': [
                      {
                        'studentName': 'Published student',
                        'quote': 'My university experience',
                        'destination': 'Canada'
                      }
                    ]
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  testWidgets('offices use published settings, including support hours',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: PublicStudentContentScreen(offices: true)));
      await tester.pumpAndSettle();
      expect(find.text('Published office address'), findsOneWidget);
      expect(find.text('09:00–17:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(
                  request.url.path.endsWith('/content/site-settings'), isTrue);
              return http.Response(
                  jsonEncode({
                    'officeLocations': 'Published office address',
                    'supportHours': '09:00–17:00'
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('empty offices do not invent a location', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: PublicStudentContentScreen(offices: true)));
      await tester.pumpAndSettle();
      expect(
          find.text('No office locations are published yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => http.Response('{}', 200,
            headers: {'content-type': 'application/json'})));
  });
}
