import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart'; 
import 'package:study_birds/data/study_birds_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final role in ['parent', 'university', 'employee']) {
    test('$role signs in and restores its own role', () async {
      final api = StudyBirdsApi(
          client: MockClient((request) async => http.Response(
              jsonEncode({
                'token': 'session',
                'user': {'_id': role, 'role': role}
              }),
              200)));
      addTearDown(api.dispose);
      await api.authenticate('account@example.test', 'password',
          accountRole: role);
      expect(api.role, role);
      await api.restore();
      expect(api.authenticated, isTrue);
      expect(api.role, role);
    });
  }
  test('choosing a different account type never changes server privileges',
      () async {
    final api = StudyBirdsApi(
        client: MockClient((request) async => http.Response(
            '{"token":"session","user":{"role":"student"}}', 200)));
    addTearDown(api.dispose);
    await expectLater(
        api.authenticate('student@example.test', 'password',
            accountRole: 'university'),
        throwsA(isA<ApiException>()));
    expect(api.authenticated, isFalse);
    expect(await const FlutterSecureStorage().read(key: 'study_birds_token'),
        isNull);
  });
  test(
      'login uses website credentials and sends bearer token on subsequent calls',
      () async {
    final requests = <http.Request>[];
    final api = StudyBirdsApi(client: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode(request.url.path.endsWith('/login')
              ? {
                  'token': 'session',
                  'user': {'_id': 'student-1', 'role': 'student'}
                }
              : []),
          200);
    }));
    addTearDown(api.dispose);
    await api.authenticate(' student@example.test ', 'password');
    await api.request('GET', '/students/documents');
    expect(jsonDecode(requests.first.body)['email'], 'student@example.test');
    expect(requests.last.headers['Authorization'], 'Bearer session');
    expect(api.authenticated, isTrue);
    expect(await const FlutterSecureStorage().read(key: 'study_birds_token'),
        'session');
  });
  test('failed login never creates a session', () async {
    final api = StudyBirdsApi(
        client: MockClient((_) async =>
            http.Response('{"message":"Invalid credentials"}', 401)));
    addTearDown(api.dispose);
    await expectLater(
        api.authenticate('a@b.test', 'wrong'), throwsA(isA<ApiException>()));
    expect(api.authenticated, isFalse);
  });
  test('expired session clears secure storage and user', () async {
    FlutterSecureStorage.setMockInitialValues({'study_birds_token': 'expired'});
    final api = StudyBirdsApi(
        client: MockClient(
            (_) async => http.Response('{"message":"Expired"}', 401)));
    addTearDown(api.dispose);
    await expectLater(api.restore(), throwsA(isA<ApiException>()));
    expect(api.authenticated, isFalse);
    expect(await const FlutterSecureStorage().read(key: 'study_birds_token'),
        isNull);
  });
  test('admin credentials do not open a student session', () async {
    final api = StudyBirdsApi(
        client: MockClient((_) async =>
            http.Response('{"token":"admin","user":{"role":"admin"}}', 200)));
    addTearDown(api.dispose);
    await expectLater(api.authenticate('admin@example.test', 'password'),
        throwsA(isA<ApiException>()));
    expect(api.authenticated, isFalse);
    expect(await const FlutterSecureStorage().read(key: 'study_birds_token'),
        isNull);
  });
  test('upload sends accepted MIME type and document field', () async {
    String? multipart;
    final api = StudyBirdsApi(client: MockClient((request) async {
      multipart = request.body;
      return http.Response('{}', 201);
    }));
    addTearDown(api.dispose);
    await api.upload(
        '/students/documents',
        PlatformFile(
            name: 'passport.pdf',
            size: 4,
            bytes: Uint8List.fromList([37, 80, 68, 70])),
        {'type': 'passport'});
    expect(multipart, contains('application/pdf'));
    expect(multipart, contains('name="type"'));
    expect(multipart, contains('passport'));
  });
  test('oversized uploads are rejected before networking', () async {
    final api = StudyBirdsApi(
        client: MockClient(
            (_) async => throw StateError('Network must not be called')));
    addTearDown(api.dispose);
    await expectLater(
        api.upload(
            '/students/documents',
            PlatformFile(
                name: 'large.pdf', size: 6 * 1024 * 1024, bytes: Uint8List(1)),
            {}),
        throwsA(isA<ApiException>()));
  });
  test('non-JSON failure produces a readable error', () async {
    final api = StudyBirdsApi(
        client: MockClient(
            (_) async => http.Response('<html>Bad gateway</html>', 502)));
    addTearDown(api.dispose);
    await expectLater(
        api.request('GET', '/mobile/config'), throwsA(isA<ApiException>()));
  });

  // ── Account deletion ────────────────────────────────────────────────────────

  // Returns a mock that replies with a valid student user for /auth/me and
  // delegates every other request to [other].
  MockClient withMeStub(
      Future<http.Response> Function(http.Request) other) {
    return MockClient((req) async {
      if (req.url.path.endsWith('/auth/me')) {
        return http.Response(
            jsonEncode({'user': {'_id': 'u1', 'role': 'student'}}), 200);
      }
      return other(req);
    });
  }

  test('deleteAccount sends DELETE to /auth/account with password in body',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'study_birds_token': 'live-token'});
    http.Request? captured;
    final api = StudyBirdsApi(
        client: withMeStub((req) async {
          captured = req;
          return http.Response('{}', 200);
        }),
        storage: const FlutterSecureStorage());
    addTearDown(api.dispose);
    await api.restore();
    await api.deleteAccount('correctPassword');
    expect(captured, isNotNull);
    expect(captured!.method, 'DELETE');
    expect(captured!.url.path, endsWith('/auth/account'));
    final body = jsonDecode(captured!.body) as Map;
    expect(body['password'], 'correctPassword');
    expect(captured!.headers['Authorization'], 'Bearer live-token');
  });

  test('deleteAccount clears the session on 200', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'study_birds_token': 'live-token'});
    final api = StudyBirdsApi(
        client: withMeStub((_) async => http.Response('{}', 200)),
        storage: const FlutterSecureStorage());
    addTearDown(api.dispose);
    await api.restore();
    expect(api.authenticated, isTrue);
    await api.deleteAccount('correctPassword');
    expect(api.authenticated, isFalse);
    expect(
        await const FlutterSecureStorage().read(key: 'study_birds_token'),
        isNull);
  });

  test('deleteAccount with wrong password keeps session alive', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'study_birds_token': 'live-token'});
    final api = StudyBirdsApi(
        client: withMeStub((_) async =>
            http.Response('{"message":"Invalid password"}', 401)),
        storage: const FlutterSecureStorage());
    addTearDown(api.dispose);
    await api.restore();
    expect(api.authenticated, isTrue);
    await expectLater(
        api.deleteAccount('wrongPassword'), throwsA(isA<ApiException>()));
    // Session must survive a wrong-password attempt.
    expect(api.authenticated, isTrue);
    expect(
        await const FlutterSecureStorage().read(key: 'study_birds_token'),
        'live-token');
  });

  test('deleteAccount with empty password throws without any network call',
      () async {
    final api = StudyBirdsApi(
        client: MockClient((_) async {
          throw StateError('Network must not be called');
        }));
    addTearDown(api.dispose);
    await expectLater(api.deleteAccount(''), throwsA(isA<ApiException>()));
  });

  test('deleteAccount path is always /auth/account — never /auth/account/{id}',
      () async {
    FlutterSecureStorage.setMockInitialValues({'study_birds_token': 'tok'});
    final paths = <String>[];
    final api = StudyBirdsApi(
        client: withMeStub((req) async {
          paths.add(req.url.path);
          return http.Response('{}', 200);
        }),
        storage: const FlutterSecureStorage());
    addTearDown(api.dispose);
    await api.restore();
    await api.deleteAccount('pass');
    // Path must end with /auth/account exactly — no trailing ID segment.
    expect(paths.last, endsWith('/auth/account'));
    expect(paths.last, isNot(matches(RegExp(r'/auth/account/.+'))));
  });
}
