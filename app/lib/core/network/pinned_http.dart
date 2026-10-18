import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting, kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../services/error_reporter.dart';

/// Certificate pinning for the API connection.
///
/// By default Dart trusts every CA the device trusts - including CAs a user (or
/// malware) installed on the phone, which is how HTTPS traffic of a banking-like
/// app gets intercepted. This restricts API connections to an explicit
/// allow-list of ROOT certificates ([assetPath]): the Google Trust Services,
/// GlobalSign, ISRG (Let's Encrypt) and DigiCert roots that Render's public
/// certificates chain to.
///
/// Pinning the *roots* (not the leaf or intermediate) is deliberate: the server
/// certificate renews every ~60 days and intermediates rotate, but the root
/// stays - so this survives routine renewals without an app update.
///
/// Release builds require HTTPS and pinning. Missing or invalid trust bundles
/// fail closed. Only development builds may disable pinning for local testing.
class PinnedHttp {
  PinnedHttp._();

  static const assetPath = 'assets/certs/trusted_roots.pem';
  static const _enabledFlag =
      bool.fromEnvironment('API_PINNING', defaultValue: true);

  /// Replaced in tests.
  static Future<Uint8List> Function() loadBundle = _loadAsset;
  static bool Function() isEnabled = _defaultEnabled;

  static Future<SecurityContext?>? _context;

  static bool _defaultEnabled() =>
      _enabledFlag && !Platform.environment.containsKey('FLUTTER_TEST');

  static Future<Uint8List> _loadAsset() async =>
      (await rootBundle.load(assetPath)).buffer.asUint8List();

  /// The pinned context, or null when explicitly disabled in development.
  static Future<SecurityContext?> context() => _context ??= _build();

  static Future<SecurityContext?> _build() async {
    if (kReleaseMode && !isEnabled()) {
      throw const HandshakeException('Certificate pinning is required');
    }
    if (!isEnabled()) return null;
    try {
      return contextFromPem(await loadBundle());
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'pinned_http.build');
      throw const HandshakeException('Certificate trust bundle unavailable');
    }
  }

  /// A context that trusts ONLY the certificates in [pem].
  static SecurityContext contextFromPem(Uint8List pem) {
    final context = SecurityContext(withTrustedRoots: false);
    context.setTrustedCertificatesBytes(pem);
    return context;
  }

  /// Whether [url] should be pinned (https only).
  static bool appliesTo(String url) => url.startsWith('https://');

  @visibleForTesting
  static void reset() {
    _context = null;
    loadBundle = _loadAsset;
    isEnabled = _defaultEnabled;
  }

  /// A `dart:io` client for code that needs one directly (streaming/SSE).
  static Future<HttpClient> newHttpClient({String? forUrl}) async {
    if (kReleaseMode && forUrl != null && !appliesTo(forUrl)) {
      throw const HandshakeException('HTTPS is required');
    }
    final pinned =
        (forUrl == null || appliesTo(forUrl)) ? await context() : null;
    return pinned == null ? HttpClient() : HttpClient(context: pinned);
  }
}

/// Marker so tests can reset static state without exposing it in the API docs.
const visibleForTestingOnly = _VisibleForTestingOnly();

class _VisibleForTestingOnly {
  const _VisibleForTestingOnly();
}

/// `http.Client` that applies [PinnedHttp] lazily (loading the bundle is async
/// but ApiClient needs a synchronous client object).
class PinnedClient extends http.BaseClient {
  PinnedClient({String? baseUrl}) : _baseUrl = baseUrl;

  final String? _baseUrl;
  Future<http.Client>? _inner;
  bool _closed = false;

  Future<http.Client> _create() async {
    if (kReleaseMode && _baseUrl != null && !PinnedHttp.appliesTo(_baseUrl!)) {
      throw const HandshakeException('HTTPS is required');
    }
    final pinned = (_baseUrl == null || PinnedHttp.appliesTo(_baseUrl!))
        ? await PinnedHttp.context()
        : null;
    final io = pinned == null ? HttpClient() : HttpClient(context: pinned);
    io.connectionTimeout = const Duration(seconds: 15);
    return IOClient(io);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client is closed', request.url);
    if (kReleaseMode && request.url.scheme != 'https') {
      throw const HandshakeException('HTTPS is required');
    }
    final client = await (_inner ??= _create());
    return client.send(request);
  }

  @override
  void close() {
    _closed = true;
    _inner?.then<void>((client) => client.close(),
        onError: (Object _, StackTrace __) {});
  }
}
