import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/network/pinned_http.dart';

/// SHA-256 fingerprints (of the DER bytes) of the roots we intend to trust.
/// Taken from each CA's own publication; a change here is a deliberate act.
const expectedRoots = {
  'GTS Root R1': 'd947432abde7b7fa90fc2e6b59101b1280e0e1c7e4e40fa3c6887fff57a7f4cf',
  'GTS Root R2': '8d25cd97229dbf70356bda4eb3cc734031e24cf00fafcfd32dc76eb5841c7ea8',
  'GTS Root R3': '34d8a73ee208d9bcdb0d956520934b4e40e69482596e8b6f73c8426b010a6f48',
  'GTS Root R4': '349dfa4058c5e263123b398ae795573c4e1313c83fe68f93556cd5e8031b3c7d',
  'GlobalSign Root CA': 'ebd41040e4bb3ec742c9e381d31ef2a41a48b6685c96e7cef3c1df6cd4331c99',
  'ISRG Root X1': '96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6',
  'ISRG Root X2': '69729b8e15a86efc177a57afb7171dfc64add28c2fca8cf1507e34453ccb1470',
  'DigiCert Global Root G2': 'cb3ccbb76031e5e0138f8dd39a23f9de47ffc35e43c1144cea27d46a5ab1cb5f',
};

List<Uint8List> pemToDer(String pem) {
  final re = RegExp(r'-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----');
  return re
      .allMatches(pem)
      .map((m) => base64.decode(m.group(1)!.replaceAll(RegExp(r'\s'), '')))
      .toList();
}

void main() {
  final bundle = File('assets/certs/trusted_roots.pem').readAsBytesSync();

  group('trusted root bundle', () {
    test('contains exactly the intended roots (fingerprints, no extras)', () {
      final fingerprints = pemToDer(utf8.decode(bundle))
          .map((der) => sha256.convert(der).toString())
          .toSet();
      expect(fingerprints, expectedRoots.values.toSet(),
          reason: 'any added/removed/tampered root must be a conscious change');
    });

    test('loads into a SecurityContext', () {
      expect(() => PinnedHttp.contextFromPem(bundle), returnsNormally);
    });

    test('only https URLs are pinned (local http dev is untouched)', () {
      expect(PinnedHttp.appliesTo('https://study-birds1.onrender.com/api'), isTrue);
      expect(PinnedHttp.appliesTo('http://10.0.2.2:5000/api'), isFalse);
    });
  });

  group('enforcement against a real TLS handshake', () {
    late HttpServer server;
    late String url;
    HttpOverrides? previousOverrides;

    setUp(() async {
      // flutter_test replaces HttpClient with a stub; we need real sockets here.
      previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final ctx = SecurityContext()
        ..useCertificateChain('test/fixtures/selfsigned_cert.pem')
        ..usePrivateKey('test/fixtures/selfsigned_key.pem');
      server = await HttpServer.bindSecure('127.0.0.1', 0, ctx);
      server.listen((request) {
        request.response
          ..statusCode = 200
          ..write('ok')
          ..close();
      });
      url = 'https://localhost:${server.port}';
      PinnedHttp.reset();
      PinnedHttp.isEnabled = () => true;
    });

    tearDown(() async {
      await server.close(force: true);
      PinnedHttp.reset();
      HttpOverrides.global = previousOverrides;
    });

    test('a server whose certificate does not chain to a pinned root is REFUSED',
        () async {
      PinnedHttp.loadBundle = () async => bundle; // the real allow-list
      final client = PinnedClient(baseUrl: url);
      addTearDown(client.close);
      await expectLater(client.get(Uri.parse('$url/')), throwsA(anything),
          reason: 'an interception certificate must not be accepted');
    });

    test('the same server IS accepted when its certificate is the pinned one',
        () async {
      final fixture = File('test/fixtures/selfsigned_cert.pem').readAsBytesSync();
      PinnedHttp.loadBundle = () async => fixture;
      final client = PinnedClient(baseUrl: url);
      addTearDown(client.close);
      final response = await client.get(Uri.parse('$url/'));
      expect(response.statusCode, 200);
      expect(response.body, 'ok');
    });

    test('pinning disabled (kill switch) => normal system validation only',
        () async {
      PinnedHttp.isEnabled = () => false;
      final client = PinnedClient(baseUrl: url);
      addTearDown(client.close);
      // The system store does not know our self-signed cert either, so this
      // still fails - proving the kill switch only removes the extra
      // restriction and never weakens normal TLS validation.
      await expectLater(client.get(Uri.parse('$url/')), throwsA(anything));
    });

    test('an unreadable bundle falls back to normal validation (never bricks)',
        () async {
      PinnedHttp.loadBundle = () async => throw StateError('asset missing');
      final context = await PinnedHttp.context();
      expect(context, isNull);
    });
  });
}
