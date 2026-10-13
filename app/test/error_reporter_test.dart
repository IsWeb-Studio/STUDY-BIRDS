import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/error_reporter.dart';
import 'package:study_birds/core/utils/app_error.dart';

void main() {
  late List<String> reported;

  setUp(() {
    ErrorReporter.resetForTest();
    reported = [];
    ErrorReporter.sink = (error, stack, where, extra) =>
        reported.add('$where|${error.runtimeType}');
  });
  tearDown(ErrorReporter.resetForTest);

  group('what is worth reporting', () {
    test('expected conditions are NOT reported', () {
      for (final e in <Object>[
        const SocketException('no route'),
        TimeoutException('slow'),
        http.ClientException('reset'),
        const ApiException(0, AppError.connection),
        const ApiException(401, 'x'),
        const ApiException(404, 'x'),
        const ApiException(409, 'x'),
        const ApiException(429, 'x'),
        const ApiException(408, 'x'),
      ]) {
        ErrorReporter.swallowed(e, null, 'test');
      }
      expect(reported, isEmpty);
    });

    test('bugs and server faults ARE reported', () {
      ErrorReporter.swallowed(StateError('boom'), null, 'a');
      ErrorReporter.swallowed(const FormatException('bad json'), null, 'b');
      ErrorReporter.swallowed(TypeError(), null, 'c');
      ErrorReporter.swallowed(const ApiException(500, 'x'), null, 'd');
      ErrorReporter.swallowed(const ApiException(422, 'x'), null, 'e');
      expect(reported.length, 5);
    });
  });

  group('flood protection', () {
    test('same place + same error type is reported once per cooldown', () {
      for (var i = 0; i < 50; i++) {
        ErrorReporter.swallowed(StateError('x$i'), null, 'loop');
      }
      expect(reported.length, 1);
    });

    test('a global per-minute cap protects the quota', () {
      for (var i = 0; i < 200; i++) {
        ErrorReporter.swallowed(StateError('x'), null, 'place-$i');
      }
      expect(reported.length, 30);
    });
  });

  group('API failures', () {
    test('5xx is reported, 4xx only leaves a breadcrumb', () {
      ErrorReporter.apiFailure('GET', '/students/applications', 503);
      ErrorReporter.apiFailure('POST', '/auth/login', 401);
      ErrorReporter.apiFailure('GET', '/x', 404);
      expect(reported, ['api GET /students/applications|StateError']);
    });

    test('routes are grouped so ids do not create endless distinct issues', () {
      expect(
          ErrorReporter.normalizePath(
              '/applications/64f0c0ffee64f0c0ffee1234/documents/12?token=abc'),
          '/applications/:id/documents/:n');
    });
  });

  test('ApiClient reports a real 5xx through the central reporter', () async {
    // Uses a fake transport; proves the wiring, not just the helper.
    final api = ApiClient.forTesting(_Fake(503));
    await expectLater(api.post('/payments/intent', body: {}),
        throwsA(isA<ApiException>()));
    expect(reported, ['api POST /payments/intent|ApiException']);
  });

  test('a server error text never reaches the log redaction untouched', () {
    expect(AppError.redact('token=abc123 user@mail.com'),
        isNot(contains('abc123')));
  });
}

class _Fake extends http.BaseClient {
  _Fake(this.status);
  final int status;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(const <int>[]), status);
}
