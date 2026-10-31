import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/home_journey/student_menu.dart';
import 'package:study_birds/screens/stories/friends_screen.dart';

void main() {
  for (final locale in ['ar', 'en']) {
    testWidgets(
        '$locale menu exposes friends immediately and sponsor below logout with large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget? destination;
      await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: StudentMenuPanel(
                  onClose: () {},
                  onLogout: () {},
                  onOpen: (screen) => destination = screen))));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('menu-refer-friends'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(destination, isA<FriendsScreen>());
      final logout = tester.getRect(find.byKey(const ValueKey('menu-logout')));
      final sponsor = tester.getRect(find.text('Sponsored by Study Birds'));
      expect(sponsor.top, greaterThanOrEqualTo(logout.bottom));
      expect(sponsor.bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });
  }
}
