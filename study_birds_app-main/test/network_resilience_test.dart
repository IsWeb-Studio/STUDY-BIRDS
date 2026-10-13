import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/app_error.dart';

ApiClient clientWith(Future<http.Response> Function(http.Request) handler) =>
    ApiClient.forTesting(MockClient(handler));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('error mapping', () {
    test('transport failures map to the friendly offline message', () {
      expect(AppError.message(const SocketException('Failed host lookup')),
          AppError.connection);
      expect(AppError.message(const HandshakeException('tls')),
          AppError.connection);
      expect(AppError.message(http.ClientException('reset')),
          AppError.connection);
      expect(AppError.message(TimeoutException('x')), AppError.timeout);
      expect(AppError.message(StateError('secret internals')),
          AppError.unexpected);
    });

    test('status codes: server down, rate limit, unauthorized, unexpected', () {
      expect(AppError.response(0, ''), AppError.connection);
      expect(AppError.response(503, 'boom'), AppError.unavailable);
      expect(AppError.response(504, ''), AppError.timeout);
      expect(AppError.response(429, ''), contains('انتظر'));
      expect(AppError.response(401, ''), contains('سجّل الدخول'));
      expect(AppError.response(403, ''), contains('لا يمكنك'));
      expect(AppError.response(418, 'weird'), AppError.unexpected);
    });

    test('developer logs never contain tokens, emails or passwords', () {
      final redacted = AppError.redact(
          'Authorization: Bearer abc.def-123 user a.b@mail.com password=hunter2 '
          'token: "xyz" jwt eyJhbGciOi.eyJzdWIiOi.sig');
      expect(redacted, isNot(contains('abc.def-123')));
      expect(redacted, isNot(contains('a.b@mail.com')));
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, isNot(contains('xyz')));
      expect(redacted, isNot(contains('eyJhbGciOi')));
    });
  });

  group('ApiClient reliability', () {
    test('GET retries transport failures with bounded attempts then succeeds',
        () async {
      var calls = 0;
      final api = clientWith((r) async {
        if (++calls < 3) throw http.ClientException('connection reset');
        return http.Response('{"ok":true}', 200);
      });
      expect(await api.get('/x', cached: false), {'ok': true});
      expect(calls, 3);
    });

    test('GET gives up after the retry budget -> friendly connection error',
        () async {
      var calls = 0;
      final api = clientWith((r) async {
        calls++;
        throw const SocketException('Network is unreachable');
      });
      await expectLater(
          api.get('/x', cached: false),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'status', 0)
              .having((e) => e.message, 'message', AppError.connection)));
      expect(calls, 3, reason: '1 try + 2 retries, never unbounded');
    });

    test('identical concurrent GETs share a single request', () async {
      var calls = 0;
      final gate = Completer<void>();
      final api = clientWith((r) async {
        calls++;
        await gate.future;
        return http.Response('[1,2]', 200);
      });
      final results = Future.wait(
          List.generate(5, (_) => api.get('/list', cached: false)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      expect((await results).every((r) => r.length == 2), isTrue);
      expect(calls, 1);
    });

    test('writes are never auto-retried (no duplicate payments/accounts/OTP)',
        () async {
      var calls = 0;
      final api = clientWith((r) async {
        calls++;
        throw http.ClientException('lost');
      });
      await expectLater(api.post('/payments', body: {'a': 1}),
          throwsA(isA<ApiException>()));
      expect(calls, 1);
    });

    test('server errors (503) are not retried blindly and show safe text',
        () async {
      var calls = 0;
      final api = clientWith((r) async {
        calls++;
        return http.Response('{"message":"MongoServerError E11000"}', 503);
      });
      await expectLater(
          api.get('/x', cached: false),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', AppError.unavailable)));
      expect(calls, 1);
    });

    test('mutating requests carry an idempotency key; reads do not; keys differ',
        () async {
      final seen = <String?>[];
      final api = clientWith((r) async {
        seen.add(r.headers['Idempotency-Key']);
        return http.Response('{}', 200);
      });
      await api.post('/a', body: {});
      await api.post('/a', body: {});
      await api.get('/a', cached: false);
      await api.post('/a', body: {}, idempotencyKey: 'draft-1');
      await api.post('/a', body: {}, idempotencyKey: 'draft-1');
      expect(seen[0], isNotNull);
      expect(seen[0], isNot(seen[1]));
      expect(seen[2], isNull);
      expect(seen[3], 'draft-1');
      expect(seen[4], 'draft-1');
    });

    test('401 re-send after token refresh reuses the same idempotency key',
        () async {
      final keys = <String?>[];
      final api = clientWith((r) async {
        keys.add(r.headers['Idempotency-Key']);
        return http.Response('{}', keys.length == 1 ? 401 : 200);
      });
      api.refreshSession = (_) async => 'new-token';
      await api.post('/a', body: {}, token: 'old');
      expect(keys.length, 2);
      expect(keys[0], keys[1]);
    });

    test('a failed request does not poison the cache or later requests',
        () async {
      var fail = true;
      final api = clientWith((r) async {
        if (fail) throw http.ClientException('down');
        return http.Response('{"v":1}', 200);
      });
      await expectLater(api.get('/c'), throwsA(isA<ApiException>()));
      fail = false;
      expect(await api.get('/c'), {'v': 1});
    });

    test('upload: connection loss mid-upload surfaces an error, never success',
        () async {
      // Uploads open their own client (so they can be aborted); the zone
      // client lets the test stand in for the dropped connection.
      await http.runWithClient(() async {
        await expectLater(
            ApiClient.instance.postMultipart('/documents',
                fileBytes: utf8.encode('data'), fileName: 'a.pdf'),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 'status', 0)));
      }, () => MockClient((r) async => throw http.ClientException('lost')));
    });
  });

  group('session preservation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Map<String, String> savedSession(String role) => {
          'active_session_token': 'tok',
          'refresh_token': 'ref',
          'cached_user': jsonEncode({
            'savedAt': DateTime.now().toUtc().toIso8601String(),
            'user': {
              'id': 'u1',
              'name': 'Sara',
              'email': 'sara@example.test',
              'role': role,
              'hasPassword': true,
            },
          }),
        };

    test('offline start keeps a student signed in and keeps credentials',
        () async {
      FlutterSecureStorage.setMockInitialValues(savedSession('student'));
      final session = AuthSession.instance;
      session.currentUser = null;
      session.token = null;
      session.debugResetRestore();
      await session.restore();
      expect(session.currentUser, isNotNull,
          reason: 'offline must not log the user out');
      expect(session.token, 'tok');
      expect(session.restoreNeedsNetwork, isFalse);
      expect(
          await const FlutterSecureStorage().read(key: 'refresh_token'), 'ref');
    });

    test(
        'offline start for staff keeps stored credentials and asks for a retry '
        '(no logout, no fake offline access)', () async {
      FlutterSecureStorage.setMockInitialValues(savedSession('employee'));
      final session = AuthSession.instance;
      session.currentUser = null;
      session.token = null;
      session.debugResetRestore();
      await session.restore();
      expect(session.currentUser, isNull,
          reason: 'staff permissions are never trusted from the cache');
      expect(session.restoreNeedsNetwork, isTrue);
      expect(
          await const FlutterSecureStorage().read(key: 'refresh_token'), 'ref');
      expect(
          await const FlutterSecureStorage().read(key: 'active_session_token'),
          'tok');
    });

    test('connection failures are reported truthfully, credentials are not',
        () {
      final session = AuthSession.instance;
      session.reportAuthFailure(const ApiException(0, AppError.connection));
      expect(session.takeAuthFailure(), AppError.connection);
      expect(session.takeAuthFailure(), isNull, reason: 'consumed once');
      session.reportAuthFailure(const ApiException(401, 'Invalid credentials'));
      expect(session.takeAuthFailure(), isNull,
          reason: 'wrong password keeps the credentials message');
      session.reportAuthFailure(const ApiException(503, 'x'));
      expect(session.takeAuthFailure(), AppError.unavailable);
      session.reportAuthFailure(const ApiException(408, 'x'),
          mayHaveCompleted: true);
      expect(session.takeAuthFailure(), contains('أُنشئ'));
    });
  });

  group('offline UI', () {
    testWidgets('ErrorState shows the professional offline state and Try Again',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ErrorState(
                  message: AppError.connection, onRetry: () => retries++))));
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.textContaining('يرجى التحقق من اتصالك بالإنترنت'),
          findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      await tester.tap(find.text('إعادة المحاولة'));
      // "Try again" verifies connectivity first (bounded to 4s), then retries.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('non-network errors keep the generic (safe) state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ErrorState(message: 'Mongo E11000 stack'))));
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
      expect(find.textContaining('Mongo'), findsNothing);
      expect(find.text('إعادة المحاولة'), findsNothing,
          reason: 'no retry callback => no dead button');
    });
  });
}
