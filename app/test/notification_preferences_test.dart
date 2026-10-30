import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/notification_preferences_store.dart';
import 'package:study_birds/core/services/notification_scheduler.dart';
import 'package:study_birds/screens/profile_account/notification_preferences_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'notif_pref_payments': false});
    FlutterSecureStorage.setMockInitialValues({});
    AuthSession.instance.token = 'preferences-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'first',
        name: 'First',
        email: 'first@example.test',
        role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });

  test(
      'preferences belong to each account and ignore unattributable legacy keys',
      () async {
    expect(
        (await NotificationPreferencesStore.read('first'))['payments'], true);
    await NotificationPreferencesStore.save(
        'first', {'payments': false, 'security': false});
    expect(
        (await NotificationPreferencesStore.read('first'))['payments'], false);
    expect(
        (await NotificationPreferencesStore.read('second'))['payments'], true);
    expect(
        (await NotificationPreferencesStore.read('first'))
            .containsKey('security'),
        false);
    expect(await isNotificationCategoryEnabled('security'), true);
    expect(await isNotificationCategoryEnabled('urgent'), true);
    expect(
        NotificationScheduler.categoryForPath('/student/payments'), 'payments');
    expect(NotificationScheduler.categoryForPath('/student/security'), null);
  });

  testWidgets('first server read preserves and uploads this account local preferences',
      (tester) async {
    await NotificationPreferencesStore.save('first', {
      'payments': false,
      'announcements': false,
    });
    var getCount = 0;
    var putCount = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: NotificationPreferencesScreen()));
      await tester.pumpAndSettle();
      expect(getCount, 1);
      expect(putCount, 1);
      final announcementFinder =
          find.byKey(const ValueKey('notification-pref-announcements'));
      await tester.scrollUntilVisible(announcementFinder, 300);
      expect(
          tester
              .widget<SwitchListTile>(
                  announcementFinder)
              .value,
          false);
      expect(getCount, 1);
      expect(putCount, 1);
      expect(
          (await NotificationPreferencesStore.read('first'))['payments'],
          false);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
          if (request.method == 'GET') {
            getCount++;
            return http.Response(
                jsonEncode({...NotificationPreferencesStore.defaults(), '_initialized': false}),
                200,
                headers: {'content-type': 'application/json'});
          }
          if (request.method == 'PUT') {
            putCount++;
            final body = Map<String, bool>.from(jsonDecode(request.body) as Map);
            expect(body['payments'], false);
            expect(body['announcements'], false);
            return http.Response(
                jsonEncode({...NotificationPreferencesStore.defaults(), ...body, '_initialized': true}),
                200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('', 404);
        }));
  });

  testWidgets(
      'save is pending until confirmed and a failure rolls the switch back',
      (tester) async {
    final pending = Completer<http.Response>();
    final defaults = NotificationPreferencesStore.defaults();
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: NotificationPreferencesScreen()));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('notification-pref-payments'));
      var tile = tester.widget<SwitchListTile>(finder);
      expect(tile.value, true);
      tile.onChanged!(false);
      await tester.pump();
      tile = tester.widget<SwitchListTile>(finder);
      expect(tile.value, false);
      expect(tile.onChanged, null);
      pending.complete(http.Response('{"message":"failure"}', 400,
          headers: {'content-type': 'application/json'}));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, true);
      expect(
          (await NotificationPreferencesStore.read('first'))['payments'], true);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') return pending.future;
              return http.Response(jsonEncode(defaults), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets('a response arriving after an account switch is ignored',
      (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: NotificationPreferencesScreen()));
      await tester.pump();
      final logout = AuthSession.instance.logout(revoke: false);
      await tester.pump();
      await tester.runAsync(() => logout);
      AuthSession.instance.currentUser = const AuthUser(
          id: 'second',
          name: 'Second',
          email: 'second@example.test',
          role: UserRole.student);
      pending.complete(http.Response(
          jsonEncode({
            ...NotificationPreferencesStore.defaults(),
            'payments': false,
          }),
          200,
          headers: {'content-type': 'application/json'}));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect((await NotificationPreferencesStore.read('second'))['payments'],
          true);
      expect(
          (await NotificationPreferencesStore.read('first'))['payments'], true);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) => pending.future));
  });

  testWidgets('confirmed preferences persist only for the signed-in account',
      (tester) async {
    final values = NotificationPreferencesStore.defaults();
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: NotificationPreferencesScreen()));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('notification-pref-payments'));
      tester.widget<SwitchListTile>(finder).onChanged!(false);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, false);
      expect((await NotificationPreferencesStore.read('first'))['payments'],
          false);
      expect((await NotificationPreferencesStore.read('second'))['payments'],
          true);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') {
                values.addAll(
                    Map<String, bool>.from(jsonDecode(request.body) as Map));
              }
              return http.Response(jsonEncode(values), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets(
      'offline load uses only this account cache and retry fetches fresh preferences',
      (tester) async {
    await NotificationPreferencesStore.save('first', {'payments': false});
    await NotificationPreferencesStore.save('second', {'documents': false});
    var recovered = false;
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: NotificationPreferencesScreen()));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('notification-pref-payments'));
      expect(tester.widget<SwitchListTile>(finder).value, false);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      recovered = true;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(finder).value, true);
      expect(find.text('إعادة المحاولة'), findsNothing);
      expect((await NotificationPreferencesStore.read('second'))['documents'],
          false);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (!recovered) throw http.ClientException('Offline');
              return http.Response(
                  jsonEncode(NotificationPreferencesStore.defaults()), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets(
      'a late save after logout cannot change cached preferences or show a save error',
      (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: NotificationPreferencesScreen()));
      await tester.pumpAndSettle();
      tester
          .widget<SwitchListTile>(
              find.byKey(const ValueKey('notification-pref-payments')))
          .onChanged!(false);
      await tester.pump();
      final logout = AuthSession.instance.logout(revoke: false);
      await tester.pump();
      await tester.runAsync(() => logout);
      pending.complete(http.Response(
          jsonEncode(
              {...NotificationPreferencesStore.defaults(), 'payments': false}),
          200,
          headers: {'content-type': 'application/json'}));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
          (await NotificationPreferencesStore.read('first'))['payments'], true);
      expect(
          find.text('تعذر حفظ تفضيلات الإشعارات. حاول مجددًا.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') return pending.future;
              return http.Response(
                  jsonEncode(NotificationPreferencesStore.defaults()), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
