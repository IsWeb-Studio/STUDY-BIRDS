import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/services_support/student_listings_screen.dart';
import 'package:study_birds/screens/services_support/alumni_directory_screen.dart';

void main() {
  testWidgets('student sees live offer conditions and expiry', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentListingsScreen(kind: 'offer')));
      await tester.pumpAndSettle();
      expect(find.text('خصم الطالب'), findsOneWidget);
      expect(find.text('بطاقة طالب سارية'), findsOneWidget);
      expect(find.text('ينتهي في: 2099-01-01'), findsOneWidget);
    }, () => MockClient((request) async {
      expect(request.url.queryParameters['kind'], 'offer');
      return http.Response(jsonEncode([{'title': 'خصم الطالب', 'terms': 'بطاقة طالب سارية', 'expiresAt': '2099-01-01T00:00:00Z'}]),
        200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });
  testWidgets('directory filters mentors using the authenticated API', (tester) async {
    final queries = <String?>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AlumniDirectoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('خريج تجريبي'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(queries.last, 'true');
    }, () => MockClient((request) async {
      queries.add(request.url.queryParameters['mentoring']);
      return http.Response(jsonEncode([{'user': {'name': 'خريج تجريبي'}, 'openToMentoring': true}]),
        200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });
}
