import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/home_dashboard_screen.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/programs_screens.dart';
import 'smart_home_test.dart' show overview, reply, phone;

void main() {
  for (final mode in ['empty', 'application', 'legacy', 'summary']) {
    testWidgets('dashboard journey CTA routes correctly: $mode',
        (tester) async {
      phone(tester);
      AuthSession.instance.token = 'synthetic-journey-test';
      addTearDown(() => AuthSession.instance.token = null);
      final data = overview();
      (data['stats'] as Map)['currentApplications'] = mode == 'empty' ? 0 : 1;
      if (mode == 'application') {
        data['recentApplications'] = [
          {
            '_id': 'chosen-application',
            'status': 'submitted',
            'program': {'title': 'Test program'}
          }
        ];
      }
      if (mode == 'summary') {
        data['home'] = {
          'currentJourney': {'applicationId': 'chosen-application'}
        };
      }
      await http.runWithClient(() async {
        await tester.pumpWidget(
            const MaterialApp(home: HomeDashboardScreen(embedInShell: true)));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, 'متابعة الرحلة');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        if (mode == 'empty') {
          expect(find.byType(ProgramsExplorerScreen), findsOneWidget);
          expect(find.byType(JourneyTrackerScreen), findsNothing);
        } else {
          final screen = tester
              .widget<JourneyTrackerScreen>(find.byType(JourneyTrackerScreen));
          expect(screen.applicationId,
              mode == 'legacy' ? isNull : 'chosen-application');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async => reply(
              request.url.path.endsWith('/students/overview')
                  ? data
                  : <dynamic>[])));
    });
  }
}
