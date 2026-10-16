import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/journey_requirements_view.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  final application = <String, dynamic>{
    '_id': 'requested-application',
    'status': 'submitted',
    'program': {'title': 'Software engineering'},
  };
  http.Response response() => http.Response(jsonEncode(application), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  for (final hasSnapshot in [false, true]) {
    testWidgets(
        'rapid journey taps open one application immediately (snapshot=$hasSnapshot)',
        (tester) async {
      AuthSession.instance.token = 'journey-navigation-test';
      addTearDown(() => AuthSession.instance.token = null);
      final routes = _Routes();
      final pending = Completer<http.Response>();
      final paths = <String>[];
      var refreshes = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            navigatorObservers: [routes],
            home: JourneyRequirementsView(
              journeys: const [
                {
                  'applicationId': 'requested-application',
                  'title': 'My journey',
                  'stages': []
                }
              ],
              applications: hasSnapshot ? [application] : [],
              onRefresh: () async {
                refreshes++;
              },
            )));
        await tester.pumpAndSettle();
        final button =
            find.widgetWithText(OutlinedButton, 'مراجعة الطلب والمستندات');
        await tester.ensureVisible(button);
        // Retain the same callback to reproduce multiple taps before a rebuild.
        final press = tester.widget<OutlinedButton>(button).onPressed!;
        press();
        press();
        press();
        press();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(routes.pushes, 1);
        expect(find.byType(ApplicationDetailScreen), findsOneWidget);
        expect(paths, ['/api/applications/requested-application']);
        expect(pending.isCompleted, false,
            reason: 'navigation must not wait for the network');
        if (hasSnapshot) {
          expect(find.text('Software engineering'), findsWidgets);
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        }
        pending.complete(response());
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(ApplicationDetailScreen)))
            .pop();
        await tester.pumpAndSettle();
        expect(find.byType(JourneyRequirementsView), findsOneWidget);
        expect(refreshes, 1);
        // The navigation lock must release after returning.
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(routes.pushes, 2);
        expect(paths.length, 2);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) {
                paths.add(request.url.path);
                return pending.future;
              }));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('direct application load shows a retry after failure',
      (tester) async {
    AuthSession.instance.token = 'journey-retry-test';
    addTearDown(() => AuthSession.instance.token = null);
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: ApplicationDetailScreen.byId(
              applicationId: 'requested-application')));
      await tester.pumpAndSettle();
      expect(find.text('تعذر تحميل الطلب. أعد المحاولة.'), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Software engineering'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async =>
            ++calls == 1 ? http.Response('{}', 503) : response()));
    expect(tester.takeException(), isNull);
  });
}
