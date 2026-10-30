import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
        '$language new post labels its required text and explains invalid input',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ar = language == 'ar';
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const CommunityComposeScreen(),
      ));
      final body = find.byKey(const ValueKey('community-post-body'));
      final publish = find.widgetWithText(FilledButton, ar ? 'نشر' : 'Publish');
      expect(find.text(ar ? '* إجباري' : '* Required'), findsOneWidget);
      expect(find.text(ar ? 'العنوان (اختياري)' : 'Title (optional)'),
          findsOneWidget);
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'An optional title');
      await tester.pump();
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);
      await tester.enterText(body, '   ');
      await tester.pump();
      expect(tester.widget<TextField>(body).decoration!.errorText, isNotNull);
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);

      await tester.enterText(body, 'My post text');
      await tester.pump();
      expect(tester.widget<TextField>(body).decoration!.errorText, isNull);
      expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
      await tester.enterText(body, '');
      await tester.pump();
      expect(tester.widget<TextField>(body).decoration!.errorText, isNotNull);
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
