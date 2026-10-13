import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/app_error.dart';
import 'package:study_birds/core/utils/json_safe.dart';

void main() {
  group('JsonSafe', () {
    test('returns well-formed values', () {
      expect(JsonSafe.object({'user': {'a': 1}}, 'user'), {'a': 1});
      expect(JsonSafe.string({'token': 't'}, 'token'), 't');
      expect(JsonSafe.optString(5), isNull);
      expect(JsonSafe.optString('x'), 'x');
      expect(JsonSafe.list('nope'), isEmpty);
    });

    test('malformed shapes become a 502 ApiException, never a TypeError', () {
      for (final bad in <dynamic>[null, 'text', 5, [], {'user': 'str'}, {'user': null}]) {
        expect(() => JsonSafe.object(bad, 'user'),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
      }
      expect(() => JsonSafe.string({'token': 12}, 'token'), throwsA(isA<ApiException>()));
      expect(() => JsonSafe.string({'token': ''}, 'token'), throwsA(isA<ApiException>()));
      expect(AppError.message(const ApiException(502, AppError.unavailable)),
          AppError.unavailable);
    });
  });

  group('auth responses', () {
    test('a login answer with a changed shape is a clean failure', () async {
      await http.runWithClient(() async {
        await expectLater(
            AuthService.instance.loginOrThrow('a@b.test', 'Birds@Sky2026'),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 'status', 502)));
      }, () => MockClient((r) async => http.Response('{"user":"oops","token":7}', 200,
              headers: {'content-type': 'application/json'})));
    });

    test('extra / mistyped optional user fields do not crash parsing', () {
      final user = AuthUser.fromJson({
        '_id': 'u1',
        'name': 12, // wrong type
        'email': 'x@y.test',
        'role': 'student',
        'avatar': {'url': 'x'}, // wrong type
      });
      expect(user.id, 'u1');
      expect(user.name, '');
      expect(user.avatar, isNull);
    });
  });
}
