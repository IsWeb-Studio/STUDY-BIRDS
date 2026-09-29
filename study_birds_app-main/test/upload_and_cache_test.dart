import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/api_client.dart';
import 'package:study_birds/core/auth_session.dart';
import 'package:study_birds/core/secure_data_cache.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('upload reports outgoing bytes and preserves Arabic response', () async {
    final progress = <double>[];
    await http.runWithClient(() async {
      final result = await ApiClient.instance.postMultipart('/test-upload',
        fileBytes: List.filled(200000, 42), fileName: 'document.pdf', onProgress: progress.add);
      expect(result['message'], 'تم الرفع');
    }, () => MockClient((request) async {
      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      expect(request.bodyBytes.length, greaterThan(200000));
      return http.Response(jsonEncode({'message': 'تم الرفع'}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    expect(progress.every((value) => value >= 0 && value <= 1), isTrue);
    expect(progress, orderedEquals([...progress]..sort()));
  });
  test('cancelled upload never sends a request', () async {
    final cancellation = UploadCancellation()..cancel();
    await http.runWithClient(() async {
      await expectLater(ApiClient.instance.postMultipart('/test-upload',
        fileBytes: [1], fileName: 'x.pdf', cancellation: cancellation),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'cancelled', 499)));
    }, () => MockClient((_) async => throw StateError('Must not send')));
  });
  test('cached snapshots are account scoped and cleared on sign out', () async {
    await SecureDataCache.write('one', 'documents', [{'id': 1}]);
    expect(await SecureDataCache.read('two', 'documents'), isNull);
    expect(await SecureDataCache.read('one', 'documents'), [{'id': 1}]);
    await SecureDataCache.clear('one');
    expect(await SecureDataCache.read('one', 'documents'), isNull);
  });
  test('invalid and expired snapshots are ignored', () async {
    const key = 'student_snapshot_v1:one:documents';
    for (final raw in ['broken', '[]', jsonEncode({'savedAt': '2000-01-01', 'data': [1]})]) {
      await const FlutterSecureStorage().write(key: key, value: raw);
      expect(await SecureDataCache.read('one', 'documents'), isNull);
    }
  });
  test('every cached user role round trips using server vocabulary', () {
    for (final role in UserRole.values) {
      final user = AuthUser(id: 'one', name: 'Name', email: 'test@example.test', role: role);
      expect(AuthUser.fromJson(user.toJson()).role, role);
    }
  });
  test('temporary server outage restores a recent student snapshot without deleting credentials', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'active_session_token': 'saved-token',
      'refresh_token': 'saved-refresh',
      'cached_user': jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'user': {'_id': 'cached-student', 'role': 'student', 'name': 'Student', 'email': 'test@example.test'},
      }),
    });
    await http.runWithClient(() => AuthSession.instance.restore(),
      () => MockClient((_) async => http.Response('{"message":"Unavailable"}', 503)));
    expect(AuthSession.instance.currentUser?.id, 'cached-student');
    expect(await const FlutterSecureStorage().read(key: 'refresh_token'), 'saved-refresh');
  });
}
