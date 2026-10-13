import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/app_error.dart';
import 'package:study_birds/screens/profile_account/delete_account_screen.dart';

/// Behaviours that used to be covered only through the old `StudyBirdsApi`
/// layer, re-expressed on the single live stack (`ApiClient` + `AuthSession`).
void main() {
  const storage = FlutterSecureStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> signIn() async {
    AuthSession.instance.token = 'access';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'u1',
        name: 'Sara',
        email: 's@example.test',
        role: UserRole.student);
    await storage.write(key: 'active_session_token', value: 'access');
    await storage.write(key: 'refresh_token', value: 'refresh');
  }

  group('delete account', () {
    Future<void> openAndSubmit(WidgetTester tester, String password) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, password);
      await tester.tap(find.text('حذف الحساب نهائياً').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('نعم، احذف حسابي'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends DELETE /auth/account with the password in the body, '
        'then ends the local session', (tester) async {
      await signIn();
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await openAndSubmit(tester, 'Birds@Sky2026');
      }, () => MockClient((r) async {
            requests.add(r);
            return http.Response('{}', 200);
          }));
      final delete = requests.firstWhere((r) => r.method == 'DELETE');
      expect(delete.url.path, '/api/auth/account');
      expect(jsonDecode(delete.body), {'password': 'Birds@Sky2026'});
      expect(AuthSession.instance.token, isNull);
      expect(await storage.read(key: 'active_session_token'), isNull);
    });

    testWidgets('a wrong password (401) keeps the user signed in',
        (tester) async {
      await signIn();
      await http.runWithClient(() async {
        await openAndSubmit(tester, 'wrong-Pass-1');
      }, () => MockClient((r) async {
            // The session is genuinely valid: only the password is wrong. The
            // 401 triggers a silent token refresh, which succeeds, and the retry
            // is rejected again for the wrong password.
            if (r.url.path.endsWith('/auth/refresh')) {
              return http.Response(
                  jsonEncode({
                    'token': 'access2',
                    'refreshToken': 'refresh2',
                    'user': {
                      'id': 'u1',
                      'name': 'Sara',
                      'email': 's@example.test',
                      'role': 'student',
                      'hasPassword': true,
                    },
                  }),
                  200);
            }
            return http.Response('{"message":"Invalid credentials"}', 401);
          }));
      expect(find.textContaining('كلمة المرور غير صحيحة'), findsOneWidget);
      expect(AuthSession.instance.token, isNotNull,
          reason: 'a wrong password must not sign the user out');
      expect(AuthSession.instance.currentUser, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty password never reaches the network', (tester) async {
      await signIn();
      var calls = 0;
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('حذف الحساب نهائياً').last);
        await tester.pumpAndSettle();
      }, () => MockClient((r) async {
            calls++;
            return http.Response('{}', 200);
          }));
      expect(calls, 0);
      expect(find.text('نعم، احذف حسابي'), findsNothing);
    });
  });

  group('session restore', () {
    test('an expired session (401 on /auth/me and on refresh) clears '
        'secure storage and the user', () async {
      FlutterSecureStorage.setMockInitialValues({
        'active_session_token': 'expired',
        'refresh_token': 'also-expired',
      });
      AuthSession.instance.currentUser = null; // fresh app start
      AuthSession.instance.token = null;
      AuthSession.instance.debugResetRestore();
      await http.runWithClient(() async {
        await AuthSession.instance.restore();
      }, () => MockClient((r) async =>
              http.Response('{"message":"Invalid or expired refresh token"}', 401)));
      expect(AuthSession.instance.currentUser, isNull);
      expect(await storage.read(key: 'active_session_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
    });
  });

  group('uploads', () {
    test('sends the accepted MIME type and the document field', () async {
      String? body;
      await http.runWithClient(() async {
        await ApiClient.instance.postMultipart('/students/documents',
            fileBytes: [37, 80, 68, 70],
            fileName: 'passport.pdf',
            fields: {'type': 'passport'});
      }, () => MockClient((r) async {
            body = r.body;
            return http.Response('{}', 201);
          }));
      expect(body, contains('application/pdf'));
      expect(body, contains('name="type"'));
      expect(body, contains('passport'));
    });

    test('oversized or unsupported files are rejected before any request',
        () async {
      var calls = 0;
      await http.runWithClient(() async {
        await expectLater(
            ApiClient.instance.postMultipart('/students/documents',
                fileBytes: List.filled(5 * 1024 * 1024 + 1, 1),
                fileName: 'big.pdf'),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 'status', 413)));
        await expectLater(
            ApiClient.instance.postMultipart('/students/documents',
                fileBytes: [1], fileName: 'virus.exe'),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 'status', 415)));
      }, () => MockClient((r) async {
            calls++;
            return http.Response('{}', 200);
          }));
      expect(calls, 0);
    });
  });

  group('failures stay readable', () {
    test('a non-JSON error page becomes a safe message, not raw HTML', () async {
      await http.runWithClient(() async {
        final error = await ApiClient.instance
            .get('/x', cached: false)
            .then<Object?>((_) => null)
            .catchError((Object e) => e);
        expect(error, isA<ApiException>());
        final message = (error as ApiException).message;
        expect(message, isNot(contains('<')));
        expect(message, AppError.unavailable);
      }, () => MockClient((r) async => http.Response('<html>Bad gateway</html>', 502)));
    });

    test('a 2xx that is not JSON is treated as an unavailable service',
        () async {
      await http.runWithClient(() async {
        await expectLater(
            ApiClient.instance.get('/x', cached: false),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 'status', 502)));
      }, () => MockClient((r) async => http.Response('not json', 200)));
    });
  });

  test('failed sign-in leaves no session behind', () async {
    AuthSession.instance.currentUser = null;
    AuthSession.instance.token = null;
    await http.runWithClient(() async {
      await expectLater(
          AuthService.instance.loginOrThrow('a@b.test', 'bad'),
          throwsA(isA<ApiException>()));
    }, () => MockClient((r) async =>
            http.Response('{"message":"Invalid credentials"}', 401)));
    expect(AuthSession.instance.currentUser, isNull);
    expect(await storage.read(key: 'active_session_token'), isNull);
  });
}
