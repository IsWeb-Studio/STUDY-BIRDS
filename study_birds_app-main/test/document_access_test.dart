import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/document_access.dart';

void main() {
  test(
      'private document gets a fresh authorized URL without exposing the session',
      () async {
    AuthSession.instance.token = 'test-session';
    addTearDown(() => AuthSession.instance.token = null);
    await http.runWithClient(() async {
      final uri = await resolveDocumentDownload(
          '/api/documents/012345678901234567890123/access');
      expect(uri.host, 'api.cloudinary.com');
      expect(uri.toString(), isNot(contains('test-session')));
    },
        () => MockClient((request) async {
              expect(request.method, 'POST');
              expect(request.headers['authorization'], 'Bearer test-session');
              return http.Response(
                  jsonEncode({
                    'url':
                        'https://api.cloudinary.com/v1_1/test/raw/download?signature=test'
                  }),
                  200);
            }));
  });
  test('payment proof uses its own authorized access route', () async {
    await http.runWithClient(() async {
      await resolveDocumentDownload(
          '/api/payment-proofs/012345678901234567890123/access');
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/api/payment-proofs/012345678901234567890123/access');
              expect(request.method, 'POST');
              return http.Response(
                  jsonEncode({
                    'url':
                        'https://api.cloudinary.com/v1_1/test/raw/download?signature=test'
                  }),
                  200);
            }));
  });
  test('support attachment uses its own authorized access route', () async {
    await http.runWithClient(() async {
      await resolveDocumentDownload(
          '/api/support-attachments/012345678901234567890123/access');
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/api/support-attachments/012345678901234567890123/access');
              expect(request.method, 'POST');
              return http.Response(
                  jsonEncode({
                    'url':
                        'https://api.cloudinary.com/v1_1/test/raw/download?signature=test'
                  }),
                  200);
            }));
  });
  test('private URL fails closed for an unexpected download host', () async {
    await http.runWithClient(() async {
      await expectLater(
          resolveDocumentDownload(
              '/api/documents/012345678901234567890123/access'),
          throwsFormatException);
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({'url': 'https://untrusted.example/file'}), 200)));
  });
}
