import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/widgets/external_link.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/visa_travel_accommodation/accommodation_arrival_screens.dart';

void main() {
  testWidgets('invalid links show feedback instead of silently doing nothing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: Builder(
          builder: (context) => TextButton(
                onPressed: () => openExternalLink(context, 'not a link'),
                child: const Text('Open'),
              )),
    )));
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.textContaining('Could not open the link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('link feedback also works outside a Scaffold', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Material(
      child: Builder(
          builder: (context) => TextButton(
                onPressed: () => openExternalLink(context, ''),
                child: const Text('Update'),
              )),
    )));
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('housing loads from the server accommodation routes',
      (tester) async {
    final calls = <String>[];
    AuthSession.instance.token = 'housing-test';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AccommodationScreen()));
      await tester.pumpAndSettle();
      expect(
          calls,
          containsAll([
            '/api/accommodation/listings',
            '/api/accommodation/bookings/mine'
          ]));
      expect(find.text('Available room'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              calls.add(request.url.path);
              return http.Response(
                  jsonEncode(request.url.path.endsWith('/listings')
                      ? [
                          {
                            '_id': 'room',
                            'title': 'Available room',
                            'price': 100,
                            'capacity': 1
                          }
                        ]
                      : []),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
