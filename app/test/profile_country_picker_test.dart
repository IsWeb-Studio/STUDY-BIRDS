import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/profile_account/edit_profile_screen.dart';
import 'package:study_birds/screens/profile_account/profile_country_picker.dart';

const countries = <Map<String, dynamic>>[
  {'code': 'JO', 'name': 'Jordan', 'nameAr': 'الأردن'},
  {'code': 'TR', 'name': 'Turkey', 'nameAr': 'تركيا'},
];
Widget app(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: child);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.clearCache();
    AuthSession.instance.token = 'profile-picker-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'student',
        name: 'Student',
        email: 'student@example.test',
        role: UserRole.student);
  });
  tearDown(() {
    ApiClient.instance.clearCache();
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  testWidgets(
      'nationality and residence survive focused search selection and reopening',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
          app(const EditProfileScreen(section: ProfileSection.personal)));
      await tester.pumpAndSettle();
      for (final label in ['الجنسية', 'بلد الإقامة', 'الجنسية']) {
        final field = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label);
        await Scrollable.ensureVisible(tester.element(field), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.enterText(
            find.descendant(
                of: find.byType(BottomSheet), matching: find.byType(TextField)),
            'Jordan');
        await tester.pump();
        await tester.tap(find.widgetWithText(ListTile, 'الأردن'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ProfileCountryPicker), findsNothing);
        expect(tester.widget<TextField>(field).controller!.text,
            label == 'الجنسية' ? 'أردني/أردنية' : 'الأردن');
      }
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async => http.Response(
            jsonEncode(r.url.path.endsWith('/students/profile')
                ? <String, dynamic>{}
                : countries),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  testWidgets(
      'study labels are Arabic and country selection survives layout rebuild before Done',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
          app(const EditProfileScreen(section: ProfileSection.study)));
      await tester.pumpAndSettle();
      expect(find.text('الدول المستهدفة'), findsOneWidget);
      await tester.tap(find.text('+ إضافة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('country-JO')));
      await tester.pump();
      tester.view.physicalSize = const Size(900, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('country-JO')))
              .value,
          isTrue);
      await tester.enterText(
          find.byKey(const ValueKey('profile-country-search')), 'Turkey');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('country-TR')));
      await tester.pump();
      await tester.tap(find.text('تم'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'الأردن'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'تركيا'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async => http.Response(
            jsonEncode(r.url.path.endsWith('/students/profile')
                ? <String, dynamic>{}
                : countries),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
