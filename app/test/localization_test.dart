import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/services/locale_controller.dart';
import 'package:study_birds/core/widgets/state_widgets.dart';
import 'package:study_birds/core/utils/app_error.dart';
import 'package:study_birds/l10n/l10n.dart';

Widget app(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

Map<String, dynamic> arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Arabic and English define exactly the same keys, none empty', () {
    final ar = arb('ar')..removeWhere((k, _) => k.startsWith('@'));
    final en = arb('en')..removeWhere((k, _) => k.startsWith('@'));
    expect(en.keys.toSet(), ar.keys.toSet(),
        reason: 'a key missing in one language shows up as a blank/crash');
    for (final entry in {...ar, ...en}.entries) {
      expect('${entry.value}'.trim(), isNotEmpty, reason: entry.key);
    }
  });

  testWidgets('the offline state speaks English when the locale is English',
      (tester) async {
    await tester.pumpWidget(app(const Locale('en'),
        ErrorState(message: AppError.connection, onRetry: () {})));
    await tester.pumpAndSettle();
    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('Please check your internet connection and try again.'),
        findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
  });

  testWidgets('...and Arabic when the locale is Arabic', (tester) async {
    await tester.pumpWidget(app(const Locale('ar'),
        ErrorState(message: AppError.connection, onRetry: () {})));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('a widget mounted without the delegates still renders (Arabic)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ErrorState(message: AppError.connection, onRetry: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  group('LocaleController', () {
    test('English stays off until the build enables it', () async {
      final controller = LocaleController.instance;
      await controller.setLocale(const Locale('en'));
      expect(LocaleController.englishEnabled, isFalse);
      expect(controller.locale.languageCode, 'ar',
          reason: 'half-translated UI must not reach users by accident');
      expect(appTextDirection, TextDirection.rtl);
    });
  });
}
