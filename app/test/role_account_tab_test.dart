import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/current_user_avatar.dart';
import 'package:study_birds/screens/profile_account/my_streak.dart';
import 'package:study_birds/screens/profile_account/role_account_tab.dart';

void main() {
  testWidgets(
      'successful avatar upload updates the account and dashboard avatar together',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _AvatarPicker();
    AuthSession.instance.token = 'avatar-upload-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'avatar-role',
        name: 'Owner',
        email: 'owner@example.test',
        role: UserRole.parent);
    addTearDown(() {
      ImagePickerPlatform.instance = previousPicker;
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: Column(children: [
        CurrentUserAvatar(),
        Expanded(child: RoleAccountTab(onLogout: _noLogout)),
      ]))));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('role-account-change-avatar')));
      await tester.pumpAndSettle();
      expect(AuthSession.instance.currentUser?.avatar,
          'https://example.test/new-photo.png');
      expect(find.text('Profile photo updated'), findsOneWidget);
      final photos = tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is MemoryImage);
      expect(photos.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({
              'user': {
                '_id': 'avatar-role',
                'name': 'Owner',
                'email': 'owner@example.test',
                'role': 'parent',
                'avatar': 'https://example.test/new-photo.png'
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
  for (final role
      in UserRole.values.where((role) => role != UserRole.student)) {
    testWidgets(
        '$role account shows profile controls with correct activity access',
        (tester) async {
      AuthSession.instance.token = 'role-account-test';
      AuthSession.instance.currentUser = AuthUser(
        id: 'role-account-${role.name}',
        name: 'Account Owner',
        email: '${role.name}@example.test',
        role: role,
      );
      SharedPreferences.setMockInitialValues({});
      addTearDown(() {
        AuthSession.instance.token = null;
        AuthSession.instance.currentUser = null;
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: RoleAccountTab(
              showStreakAndGame: true,
              onLogout: () async {},
            ),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(const ValueKey('role-account-tab')), findsOneWidget);
        expect(find.text('Account Owner'), findsOneWidget);
        expect(find.text('${role.name}@example.test'), findsNWidgets(2));
        expect(find.byKey(const ValueKey('role-account-change-avatar')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('role-account-edit-name')),
            findsOneWidget);
        expect(
          find.byKey(ValueKey('role-account-streak-role-account-${role.name}')),
          role == UserRole.agent ? findsNothing : findsOneWidget,
        );
        expect(find.byType(MyStreakCard),
            role == UserRole.agent ? findsNothing : findsOneWidget);
        expect(find.byKey(const ValueKey('role-account-wink-game')),
            role == UserRole.agent ? findsNothing : findsOneWidget);
        if (role != UserRole.agent) {
          expect(find.text('7'), findsNothing,
              reason: 'The activity dashboard is hidden.');
          expect(find.text('1,234 points'), findsNothing,
              reason:
                  'The account must display the server-owned point balance.');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async => http.Response(
                jsonEncode({
                  'streak_days': 7,
                  'total_points': 1234,
                  'activityCalendar': []
                }),
                200,
                headers: {'content-type': 'application/json'},
              )));
    });
  }

  testWidgets('account name edit persists the authenticated account response',
      (tester) async {
    AuthSession.instance.token = 'role-account-save-test';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'employee-profile',
      name: 'Before Edit',
      email: 'employee@example.test',
      role: UserRole.employee,
    );
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    Map<String, dynamic>? sentBody;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoleAccountTab(onLogout: _noLogout)),
      ));
      await tester.tap(find.byKey(const ValueKey('role-account-edit-name')));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.enterText(field, 'After Edit');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(sentBody, {'name': 'After Edit'});
      expect(AuthSession.instance.currentUser?.name, 'After Edit');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('role-account-name')))
            .data,
        'After Edit',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH' &&
                  request.url.path.endsWith('/auth/me/profile')) {
                sentBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response(
                  jsonEncode({
                    'user': {
                      '_id': 'employee-profile',
                      'name': 'After Edit',
                      'email': 'employee@example.test',
                      'role': 'employee',
                      'permissions': [],
                      'emailVerified': false,
                      'hasPassword': true,
                    }
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response('{}', 404,
                  headers: {'content-type': 'application/json'});
            }));
  });
  testWidgets('administrator sees game streak count and the game streak rules',
      (tester) async {
    AuthSession.instance.token = 'admin-streak-rules';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'admin-streak-rules',
      name: 'Administrator',
      email: 'admin@example.test',
      role: UserRole.admin,
    );
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoleAccountTab(onLogout: _noLogout)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('7'), findsNothing);
      expect(find.text('My Streak'), findsNothing);
      expect(find.text('My points and how they count'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((_) async => http.Response(
              jsonEncode({
                'streak_days': 7,
                'total_points': 1234,
                'longestStreak': 7,
                'activityCalendar': [],
                'streakRestoresRemaining': 3,
                'streakRestoreLimit': 3,
                'timeZone': 'Europe/Istanbul',
              }),
              200,
              headers: {'content-type': 'application/json'},
            )));
  });
}

class _AvatarPicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile.fromData(
          base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='),
          path: 'avatar.png');
}

Future<void> _noLogout() async {}
