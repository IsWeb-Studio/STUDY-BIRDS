import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/admin_modules_repository.dart';
import 'package:study_birds/core/repositories/university_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';

void main() {
  setUp(() => AuthSession.instance.token = 'image-upload-contract');
  tearDown(() => AuthSession.instance.token = null);
  for (final legacy in [false, true]) {
    test('banner upload reads ${legacy ? "legacy" : "current"} URL response', () async {
      await http.runWithClient(() async {
        final url = await AdminModulesRepository.instance.uploadImage(
          '/admin/banners/upload', fileBytes: [1, 2, 3], fileName: 'chosen.png');
        expect(url, 'https://example.test/chosen.png');
      }, () => MockClient((request) async => http.Response(jsonEncode({
        'url': legacy ? {'url': 'https://example.test/chosen.png'} : 'https://example.test/chosen.png',
      }), 200, headers: {'content-type': 'application/json'})));
    });
  }
  test('university photo uses shared account avatar endpoint', () async {
    await http.runWithClient(() async {
      expect(await UniversityRepository.instance.uploadAvatar(
        fileBytes: [1, 2, 3], fileName: 'avatar.png'), 'https://example.test/avatar.png');
    }, () => MockClient((request) async {
      expect(request.url.path, endsWith('/auth/avatar'));
      expect(request.method, 'POST');
      return http.Response(jsonEncode({'user': {'avatar': 'https://example.test/avatar.png'}}), 200,
        headers: {'content-type': 'application/json'});
    }));
  });
}
