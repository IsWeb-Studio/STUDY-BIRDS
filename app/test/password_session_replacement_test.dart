import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/profile_account/security_settings_screen.dart';

void main() {
  test('logout sends captured access credentials even if refresh was rotated', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'old-refresh'});
    AuthSession.instance.token = 'access-to-revoke';
    var calls = 0;
    await http.runWithClient(() => AuthSession.instance.logout(),
        () => MockClient((request) async {
          calls++;
          expect(request.headers['authorization'], 'Bearer access-to-revoke');
          return http.Response('{"ok":true}', 200);
        }));
    expect(calls, 1);
    expect(AuthSession.instance.token, isNull);
  });

  test('logout retries with refresh credentials after access token expiration', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'valid-refresh'});
    AuthSession.instance.token = 'expired-access';
    var calls = 0;
    await http.runWithClient(() => AuthSession.instance.logout(),
        () => MockClient((request) async {
          calls++;
          if (calls == 1) {
            expect(request.headers['authorization'], 'Bearer expired-access');
            return http.Response('{"message":"expired"}', 401);
          }
          expect(request.headers['authorization'], isNull);
          expect(request.body, contains('valid-refresh'));
          return http.Response('{"ok":true}', 200);
        }));
    expect(calls, 2);
    expect(await const FlutterSecureStorage().read(key: 'pending_refresh_revocations'), isNull);
  });

  testWidgets('password change stores replacement access and refresh credentials', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final session = AuthSession.instance;
    session.token = 'old-access';
    session.currentUser = const AuthUser(
        id: 'u1', name: 'Test', email: 'user@example.test', role: UserRole.student);
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const ChangePasswordScreen()));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Old-Sparrow!2026');
      await tester.enterText(fields.at(1), 'New-Sparrow!2026');
      await tester.enterText(fields.at(2), 'New-Sparrow!2026');
      await tester.tap(find.byIcon(Icons.lock_reset_rounded).last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 20 && session.token != 'replacement-access'; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      expect(request.url.path, '/api/auth/change-password');
      expect(request.headers['authorization'], 'Bearer old-access');
      return http.Response(jsonEncode({
        'token': 'replacement-access', 'refreshToken': 'replacement-refresh',
        'user': {'_id': 'u1', 'name': 'Test', 'email': 'user@example.test',
          'role': 'student', 'hasPassword': true},
      }), 200);
    }));
    expect(session.token, 'replacement-access');
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'active_session_token'), 'replacement-access');
    expect(await storage.read(key: 'refresh_token'), 'replacement-refresh');
    expect(tester.takeException(), isNull);
  });
}
