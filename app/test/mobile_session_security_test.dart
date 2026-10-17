import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/error_reporter.dart';

const oldUser = AuthUser(
    id: 'old', name: 'Old', email: 'old@example.test', role: UserRole.student);
const newUser = AuthUser(
    id: 'new', name: 'New', email: 'new@example.test', role: UserRole.student);
http.Response userResponse(String id) => http.Response(
    jsonEncode({
      'user': {
        '_id': id,
        'name': id,
        'email': '$id@example.test',
        'role': 'student',
        'hasPassword': true,
      }
    }),
    200);

void main() {
  const storage = FlutterSecureStorage();
  final session = AuthSession.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await session.logout(revoke: false);
    session.debugResetRestore();
    ErrorReporter.resetForTest();
  });
  tearDown(ErrorReporter.resetForTest);

  test('late user refresh cannot restore identity or cache after logout',
      () async {
    session.token = 'old-access';
    session.currentUser = oldUser;
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = session.refreshCurrentUser();
      await started.future;
      await session.logout(revoke: false);
      reply.complete(userResponse('old'));
      await pending;
      expect(session.currentUser, isNull);
      expect(session.token, isNull);
      expect(await storage.read(key: 'cached_user'), isNull);
    },
        () => MockClient((_) {
              started.complete();
              return reply.future;
            }));
  });

  test('late user refresh cannot overwrite a newer account', () async {
    session.token = 'old-access';
    session.currentUser = oldUser;
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = session.refreshCurrentUser();
      await started.future;
      await session.login(newUser,
          authToken: 'new-access', refreshToken: 'new-refresh');
      reply.complete(userResponse('old'));
      await pending;
      expect(session.currentUser?.id, 'new');
      expect(session.token, 'new-access');
      expect(
          await storage.read(key: 'cached_user'), contains('new@example.test'));
    },
        () => MockClient((_) {
              started.complete();
              return reply.future;
            }));
  });

  test('late startup restore cannot recreate credentials after logout',
      () async {
    await storage.write(key: 'active_session_token', value: 'old-access');
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = session.restore();
      await started.future;
      await session.logout(revoke: false);
      reply.complete(userResponse('old'));
      await pending;
      expect(session.currentUser, isNull);
      expect(session.token, isNull);
      expect(await storage.read(key: 'active_session_token'), isNull);
      expect(await storage.read(key: 'cached_user'), isNull);
    },
        () => MockClient((_) {
              started.complete();
              return reply.future;
            }));
  });

  test('logout cleanup cannot delete newer login credentials', () async {
    session.token = 'old-access';
    session.currentUser = oldUser;
    await storage.write(key: 'refresh_token', value: 'old-refresh');
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = session.logout();
      await started.future;
      expect(await storage.read(key: 'active_session_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
      expect(await storage.read(key: 'cached_user'), isNull);
      expect(await storage.read(key: 'pending_refresh_revocations'),
          contains('old-refresh'));

      final login = session.login(newUser,
          authToken: 'new-access', refreshToken: 'new-refresh');
      reply.complete(http.Response('{"ok":true}', 200));
      await pending;
      await login;
      expect(session.currentUser?.id, 'new');
      expect(await storage.read(key: 'active_session_token'), 'new-access');
      expect(await storage.read(key: 'refresh_token'), 'new-refresh');
    },
        () => MockClient((_) {
              started.complete();
              return reply.future;
            }));
  });

  test('late token renewal cannot persist credentials after logout', () async {
    session.token = 'old-access';
    session.currentUser = oldUser;
    await storage.write(key: 'refresh_token', value: 'old-refresh');
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = session.refreshAccessToken('old-access');
      await started.future;
      await session.logout(revoke: false);
      reply.complete(http.Response(
          jsonEncode({
            'token': 'late-access',
            'refreshToken': 'late-refresh',
            'user': jsonDecode(userResponse('old').body)['user'],
          }),
          200));
      expect(await pending, isNull);
      expect(await storage.read(key: 'active_session_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
    },
        () => MockClient((_) {
              started.complete();
              return reply.future;
            }));
  });

  test('malformed responses and FormatException sources never enter telemetry',
      () async {
    final reported = <String>[];
    ErrorReporter.sink = (error, stack, where, extra) => reported.add('$error');
    final api = ApiClient.forTesting(MockClient((_) async =>
        http.Response('{"password":"AuditSecret987"} trailing', 200)));
    await expectLater(
        api.get('/audit', cached: false), throwsA(isA<ApiException>()));
    ErrorReporter.swallowed(
        const FormatException('secret=AuditSecret987', 'AuditSecret987'),
        null,
        'cache');
    expect(reported.where((text) => text.contains('FormatException')),
        hasLength(2));
    expect(reported.join(), isNot(contains('AuditSecret987')));
  });
}
