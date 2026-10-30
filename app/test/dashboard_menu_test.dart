import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/home_journey/student_menu.dart';
import 'package:study_birds/screens/universities_programs_countries/universities_screens.dart';

void main() {
  for (final width in [320.0, 600.0]) {
    testWidgets(
        'grouped menu expands, navigates and keeps logout reachable at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget? opened;
      var logout = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(
                      size: Size(width, 800),
                      textScaler: const TextScaler.linear(1.5)),
                  child: StudentMenuPanel(
                      onClose: () {},
                      onLogout: () => logout++,
                      onOpen: (screen) => opened = screen)))));
      for (final id in [
        'discover',
        'journey',
        'services',
        'visa',
        'support',
        'more'
      ]) {
        expect(find.byKey(ValueKey('menu-section-$id')), findsOneWidget);
      }
      for (final label in [
        'Profile',
        'Favorites',
        'Rewards',
        'Referrals',
        'Notifications'
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(
          find.byKey(const ValueKey('menu-item-universities')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('menu-section-discover')));
      await tester.pumpAndSettle();
      final universities = find.byKey(const ValueKey('menu-item-universities'));
      await tester.ensureVisible(universities);
      await tester.pumpAndSettle();
      await tester.tap(universities);
      expect(opened, isA<UniversitiesExplorerScreen>());
      await tester.ensureVisible(find.text('Discover and content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover and content'));
      await tester.pumpAndSettle();
      expect(universities, findsNothing);
      await tester
          .ensureVisible(find.byKey(const ValueKey('menu-section-support')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-section-support')));
      await tester.pumpAndSettle();
      final urgent = find.byKey(const ValueKey('menu-item-emergency'));
      await tester.ensureVisible(urgent);
      await tester.pumpAndSettle();
      expect(urgent, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-logout')));
      expect(logout, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
