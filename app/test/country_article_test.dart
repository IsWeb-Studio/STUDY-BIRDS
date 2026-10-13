import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:study_birds/screens/universities_programs_countries/countries_scholarships_screens.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  testWidgets(
      'country renders server article including bodies without headings',
      (tester) async {
    await mount(
        tester,
        const CountryDetailScreen(country: {
          '_id': 'country',
          'name': 'الدولة',
          'articleTitle': 'الدراسة في الدولة',
          'articleHeadings': ['شروط الدراسة'],
          'articleBodies': ['الشروط من السيرفر', 'معلومات السكن من السيرفر'],
        }));
    await tester.scrollUntilVisible(find.text('معلومات السكن من السيرفر'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('معلومات السكن من السيرفر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
