import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/screens/home_journey/student_banner_carousel.dart';

void main() {
  setUp(() => ApiClient.instance.clearCache());
  tearDown(() => ApiClient.instance.clearCache());
  testWidgets(
      'community ads exclude home content, navigate and disappear after refresh',
      (tester) async {
    var active = true;
    String? opened;
    final queries = <String>[];
    await http.runWithClient(() async {
      Widget view(int version) => MaterialApp(
          home: Scaffold(
              body: StudentBannerCarousel(
                  placement: 'community',
                  refreshVersion: version,
                  onExplore: (value) => opened = value)));
      await tester.pumpWidget(view(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Community offer'), findsOneWidget);
      expect(find.text('Home offer'), findsNothing);
      expect(find.text('Advertisement'), findsOneWidget);
      expect(queries.every((q) => q == 'placement=community'), isTrue);
      await tester.tap(find.text('Browse'));
      expect(opened, 'programs');
      active = false;
      await tester.pumpWidget(view(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Community offer'), findsNothing);
      expect(find.byType(PageView), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              queries.add(request.url.query);
              return http.Response(
                  jsonEncode([
                    {'title': 'Home offer', 'placement': 'home'},
                    if (active)
                      {
                        'title': 'Community offer',
                        'placement': 'community',
                        'actionLabel': 'Browse',
                        'destination': 'programs'
                      },
                  ]),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  testWidgets(
      'no active community ads produces no fallback promotion or blank carousel',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudentBannerCarousel(
                  placement: 'community', onExplore: (_) {}))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PageView), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });
}
