import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/catalog_repository.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_browser.dart';

void main() {
  final universities = [
    {'_id': 'u1', 'name': 'Turkey institution', 'country': {'_id': 'tr', 'name': 'Turkey'}},
    {'_id': 'u2', 'name': 'Baku institution', 'country': {'_id': 'az', 'name': 'Azerbaijan'}},
    {'_id': 'u3', 'name': 'Second Baku institution', 'country': 'az'},
    {'_id': 'orphan', 'name': 'Unknown institution', 'country': null},
  ];
  test('country totals use catalog membership, including zero, not editorial totals', () async {
    await http.runWithClient(() async {
      final countries = await CatalogRepository.instance.getCountries();
      expect(countries.map((c) => c['universityCount']), [1, 2, 0]);
    }, () => MockClient((request) async => http.Response(jsonEncode(
      request.url.path.endsWith('/universities') ? universities : [
        {'_id': 'tr', 'universityCount': 12},
        {'_id': 'az', 'universityCount': 14},
        {'_id': 'cn', 'universityCount': 30000},
      ]), 200, headers: {'content-type': 'application/json'})));
  });
  test('membership uses IDs and never falls back to another country', () {
    expect(universities.where((u) => catalogBelongsToCountry(u, 'az', true)).length, 2);
    expect(universities.where((u) => catalogBelongsToCountry(u, 'cn', true)), isEmpty);
    expect(catalogBelongsToCountry({'university': universities.first}, 'az', false), false);
    expect(catalogBelongsToCountry({'country': {'name': 'Azerbaijan'}}, 'az', true), false);
  });
  testWidgets('country page excludes other countries even if API ignores filter or country is missing', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CatalogBrowser(
        universities: true, countryId: 'cn', onOpen: (_) {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Turkey institution'), findsNothing);
      expect(find.text('Baku institution'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      if (request.url.path.endsWith('/universities') && request.url.hasQuery) {
        expect(request.url.queryParameters['country'], 'cn');
      }
      return http.Response(jsonEncode(request.url.path.endsWith('/universities') ? universities : []),
        200, headers: {'content-type': 'application/json'});
    }));
  });
}
