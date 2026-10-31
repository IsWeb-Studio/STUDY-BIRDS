import '../services/response_cache.dart';
import 'dart:async';
import '../utils/app_error.dart';
import '../services/connectivity_service.dart';
import '../services/error_reporter.dart';
import 'dart:convert';
import 'pinned_http.dart';
import 'dart:io' show IOException, Platform;
import 'dart:math' show Random;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UploadCancellation {
  bool cancelled = false;
  void Function()? _abort;
  void cancel() {
    cancelled = true;
    _abort?.call();
  }
}

class _ProgressUpload extends http.MultipartRequest {
  final void Function(double)? onProgress;
  _ProgressUpload(super.method, super.url, this.onProgress);
  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(super.finalize().map((chunk) {
      sent += chunk.length;
      onProgress?.call(total == 0 ? 1 : (sent / total).clamp(0.0, 1.0));
      return chunk;
    }));
  }
}

/// Status remains available for auth/control flow; messages are safe for UI.
class ApiException implements Exception, UserFacingFailure {
  final int statusCode;
  final String _rawMessage;

  /// Extra fields from the error response body (e.g. requiresTwoFactor).
  final Map<String, dynamic> data;
  const ApiException(this.statusCode, this._rawMessage, [this.data = const {}]);
  @override
  String get message => AppError.response(statusCode, _rawMessage);

  @override
  String toString() => message;
}

/// Single place that knows the backend's base URL. When the Render URL
/// changes, this is the only line that needs editing.
class ApiClient {
  ApiClient._()
      : _fixed = null,
        _testStore = null,
        _clock = DateTime.now;

  /// Test seam: lets tests inject a fake transport.
  ApiClient.forTesting(http.Client client,
      {ResponseCacheStore? cacheStore, DateTime Function()? clock})
      : _fixed = client,
        _testStore = cacheStore,
        _clock = clock ?? DateTime.now;
  static final ApiClient instance = ApiClient._();

  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://study-birds1.onrender.com/api');

  /// Reused across all requests — avoids TCP+TLS setup per call.
  final http.Client? _fixed;
  http.Client? _shared;

  /// Under `flutter test`, `http.runWithClient` supplies a different fake client
  /// per test, so a process-wide cached client would keep serving the first
  /// test's fake. Production keeps one pooled client.
  static final bool _perCallClient =
      Platform.environment.containsKey('FLUTTER_TEST');

  http.Client get _http =>
      _fixed ??
      (_perCallClient ? http.Client() : (_shared ??= createTransport()));

  /// The transport used for API traffic: certificate-pinned in production,
  /// the zone's fake client under `flutter test`.
  static http.Client createTransport() =>
      _perCallClient ? http.Client() : PinnedClient(baseUrl: baseUrl);

  /// In-memory GET cache, isolated by session and path.
  /// Per-resource TTL, bounded size, and account isolation.
  final _cache = <String, ({DateTime at, dynamic data})>{};
  final ResponseCacheStore? _testStore;
  final DateTime Function() _clock;
  String? Function(String token)? cacheOwnerForToken;
  String? Function()? activeCacheOwner;
  final _cacheChanges = StreamController<String>.broadcast();
  Stream<String> get cacheChanges => _cacheChanges.stream;
  final _noStore = <String>{};
  final _cachedReads = <String, DateTime>{};
  final _cacheSizes = <String, int>{};
  final _statusChanges = StreamController<void>.broadcast();
  Stream<void> get cacheStatusChanges => _statusChanges.stream;
  DateTime? cachedReadFor(Iterable<String> prefixes) {
    final hits = _cachedReads.entries
        .where((e) => prefixes.any((p) => e.key.startsWith(p)))
        .map((e) => e.value)
        .toList()
      ..sort();
    return hits.isEmpty ? null : hits.first;
  }

  void _readStatus(String path, DateTime? at) {
    if (at == null) {
      _cachedReads.remove(path);
    } else {
      while (_cachedReads.length >= 160) {
        _cachedReads.remove(_cachedReads.keys.first);
      }
      _cachedReads[path] = at;
    }
    _statusChanges.add(null);
  }

  bool get _cacheEnabled => !_perCallClient || _testStore != null;
  ResponseCacheStore get _store => _testStore ?? DeviceResponseCache.instance;
  String? _scope(String? token) =>
      token == null ? 'public' : cacheOwnerForToken?.call(token);
  String _canonical(String path) {
    final uri = Uri.parse(path);
    final keys = uri.queryParametersAll.keys.toList()..sort();
    return uri
        .replace(
            queryParameters: keys.isEmpty
                ? null
                : {
                    for (final key in keys) key: uri.queryParametersAll[key]!,
                  })
        .removeFragment()
        .toString();
  }

  dynamic _copy(dynamic data) => jsonDecode(jsonEncode(data));
  void _remember(String key, CachedResponse value) {
    final size = utf8.encode(jsonEncode(value.data)).length;
    if (size > 2 * 1024 * 1024) return;
    _cache.remove(key);
    _cacheSizes.removeWhere((key, _) => !_cache.containsKey(key));
    var bytes = _cacheSizes.values.fold<int>(0, (a, b) => a + b);
    while (_cache.isNotEmpty &&
        (_cache.length >= 160 || bytes + size > 8 * 1024 * 1024)) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      bytes -= _cacheSizes.remove(oldest) ?? 0;
    }
    _cacheSizes[key] = size;
    _cache[key] = (at: value.savedAt, data: _copy(value.data));
  }

  Future<void> clearDownloadedCache() async {
    clearCache();
    if (_cacheEnabled) {
      await _store.clearPrivate();
      await _store.invalidate('public', (_) => true);
    }
  }

  Future<void> clearPrivateCache() async {
    clearCache();
    if (_cacheEnabled) {
      try {
        await _store.clearPrivate();
      } catch (_) {}
    }
  }

  final _snapshots = <String, ({DateTime at, dynamic data})>{};

  int _snapshotVersion = 0;
  int get snapshotVersion => _snapshotVersion;

  /// Recent screen data can render synchronously while an uncached refresh runs.
  dynamic snapshot(String path, {String? token}) {
    if (token == null) return null;
    final hit = _snapshots['$token:$path'];
    if (hit == null ||
        DateTime.now().difference(hit.at) > const Duration(minutes: 2)) {
      return null;
    }
    return jsonDecode(jsonEncode(hit.data));
  }

  void rememberSnapshot(String path, dynamic data,
      {String? token, int? version}) {
    if (token == null || (version != null && version != _snapshotVersion)) {
      return;
    }
    if (_snapshots.length >= 20) _snapshots.remove(_snapshots.keys.first);
    _snapshots['$token:$path'] =
        (at: DateTime.now(), data: jsonDecode(jsonEncode(data)));
  }

  void clearCache() {
    _cache.clear();
    _cacheSizes.clear();
    _cachedReads.clear();
    _lastPrivateScope = null;
    _snapshots.clear();
    _snapshotVersion++;
    _inflight.clear();
    _noStore.clear();
  }

  Future<String?> Function(String failedToken)? refreshSession;

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'X-Study-Birds-Client': 'mobile',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _authorized(
      String? token, Future<http.Response> Function(String?) send,
      {bool mayChangeData = false,
      Duration requestTimeout = const Duration(seconds: 30)}) async {
    final connectivity = ConnectivityService.instance;
    try {
      var response = await send(token).timeout(requestTimeout);
      if (response.statusCode == 401 &&
          token != null &&
          refreshSession != null) {
        final replacement = await refreshSession!(token);
        if (replacement != null) {
          response = await send(replacement).timeout(requestTimeout);
        }
      }
      connectivity.reportSuccess();
      return response;
    } on TimeoutException catch (e, s) {
      AppError.log('api', e, s);
      connectivity.reportFailure();
      throw ApiException(
          408, mayChangeData ? AppError.uncertain : AppError.timeout);
    } on IOException catch (e, s) {
      // SocketException (DNS/no route/reset), HandshakeException, HttpException…
      AppError.log('api', e, s);
      connectivity.reportFailure();
      throw const ApiException(0, AppError.connection);
    } on http.ClientException catch (e, s) {
      AppError.log('api', e, s);
      connectivity.reportFailure();
      throw const ApiException(0, AppError.connection);
    }
  }

  static final _random = Random();

  /// One key per logical user action, reused if the same request is re-sent
  /// after a 401 token refresh, so a server that supports it can de-duplicate.
  static String newOperationId() => _newOperationId();

  static String _newOperationId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 32).toRadixString(36)}';

  Future<dynamic> _request(String method, String path,
      {String? token,
      Map<String, dynamic>? body,
      String? idempotencyKey}) async {
    final owner = _scope(token);
    final mutating = method != 'GET';
    final operationId = mutating ? (idempotencyKey ?? _newOperationId()) : null;
    final response = await _authorized(token, (credential) async {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers.addAll(_headers(credential));
      if (operationId != null) request.headers['Idempotency-Key'] = operationId;
      if (body != null) request.body = jsonEncode(body);
      return await http.Response.fromStream(await _http.send(request));
    }, mayChangeData: mutating && !path.startsWith('/auth/'));
    if (method == 'GET' &&
        response.headers['cache-control']?.toLowerCase().contains('no-store') ==
            true) {
      if (_noStore.length > 160) _noStore.clear();
      _noStore.add('${token ?? ''}:$path');
    }
    return _decodeReporting(response, method, path, owner: owner);
  }

  /// Identical concurrent GETs share one request (no pile-up after reconnect).
  final _inflight = <String, Future<dynamic>>{};

  /// Bounded retry for safe (idempotent) reads only: transport failures,
  /// exponential backoff with jitter, and never while the device has no
  /// network interface at all (retrying cannot help there).
  Future<dynamic> _getWithRetry(String path, String? token) async {
    const maxRetries = 2;
    for (var attempt = 0;; attempt++) {
      try {
        return await _request('GET', path, token: token);
      } on ApiException catch (e) {
        final canRetry = e.statusCode == 0 &&
            attempt < maxRetries &&
            ConnectivityService.instance.status != NetworkStatus.offline;
        if (!canRetry) rethrow;
        final backoff = 400 * (1 << attempt);
        await Future<void>.delayed(
            Duration(milliseconds: backoff + _random.nextInt(backoff)));
      }
    }
  }

  /// Cached content can paint before network I/O, including after process death.
  /// cached:false always reads the server, but warms eligible local snapshots.
  Future<dynamic> get(String path, {String? token, bool cached = true}) async {
    final canonical = _canonical(path);
    final scope = _scope(token);
    if (token != null && scope != null) _lastPrivateScope = scope;
    final policy = _cacheEnabled && scope != null
        ? ResponseCachePolicy.forPath(canonical, private: token != null)
        : null;
    final key = '$scope:$baseUrl$canonical';
    final generation = _snapshotVersion;
    CachedResponse? saved;
    if (cached && policy != null) {
      final memory = _cache[key];
      if (memory != null) saved = CachedResponse(memory.data, memory.at);
      if (saved == null && policy.persistent) {
        try {
          saved = await _store.read(scope!, '$baseUrl$canonical');
          final latest = _cache[key];
          if (latest != null &&
              (saved == null || !latest.at.isBefore(saved.savedAt))) {
            saved = CachedResponse(latest.data, latest.at);
          }
        } catch (_) {}
        if (generation != _snapshotVersion || scope != _scope(token)) {
          return get(path, token: token, cached: false);
        }
      }
      if (saved != null && saved.valid(policy.retainFor, _clock())) {
        _remember(key, saved);
        _readStatus(canonical, saved.savedAt);
        // Paint saved content first, then revalidate once on each new process.
        if (!saved.valid(policy.freshFor, _clock()) || (memory == null)) {
          unawaited(_fetchCached(
                  path, token, canonical, scope, key, policy, generation,
                  background: true)
              .catchError((Object _, StackTrace __) => null));
        }
        return _copy(saved.data);
      }
    }
    return _fetchCached(path, token, canonical, scope, key, policy, generation);
  }

  Future<dynamic> _fetchCached(String path, String? token, String canonical,
      String? scope, String key, ResponseCachePolicy? policy, int generation,
      {bool background = false}) async {
    final flightKey = '$generation:${token ?? ''}:$canonical';
    final pending = _inflight[flightKey];
    if (pending != null) return _copy(await pending);
    final future = _getWithRetry(path, token);
    _inflight[flightKey] = future;
    try {
      final data = await future;
      if (generation == _snapshotVersion && scope == _scope(token)) {
        _readStatus(canonical, null);
      }
      if (generation == _snapshotVersion &&
          scope == _scope(token) &&
          policy != null) {
        final prohibited = _noStore.remove('${token ?? ''}:$path');
        if (!prohibited) {
          final value = CachedResponse(data, _clock());
          final changed = jsonEncode(_cache[key]?.data) != jsonEncode(data);
          _remember(key, value);
          if (policy.persistent) {
            try {
              await _store.write(scope!, '$baseUrl$canonical', value);
            } catch (_) {}
          }
          if (background && changed) _cacheChanges.add(canonical);
        } else {
          _cache.remove(key);
          try {
            await _store.invalidate(scope!, (p) => p == '$baseUrl$canonical');
          } catch (_) {}
        }
      }
      return _copy(data);
    } on ApiException catch (error) {
      if ([401, 403, 404, 410].contains(error.statusCode) &&
          generation == _snapshotVersion) {
        _cache.remove(key);
        _readStatus(canonical, null);
        if (scope != null && policy?.persistent == true) {
          try {
            await _store.invalidate(scope, (p) => p == '$baseUrl$canonical');
          } catch (_) {}
        }
        if (background) _cacheChanges.add(canonical);
      }
      rethrow;
    } finally {
      if (identical(_inflight[flightKey], future)) _inflight.remove(flightKey);
    }
  }

  /// Discard a resource when a push event announces a server-side change.
  void invalidateResource(String path) => _invalidateMutation(path);

  void _invalidateMutation(String path, {String? owner}) {
    if (!_cacheEnabled ||
        (path.startsWith('/auth/') &&
            !path.startsWith('/auth/me/profile') &&
            !path.startsWith('/auth/avatar'))) {
      return;
    }
    final p = Uri.parse(path).path;
    final roots = <String>{};
    if (p.startsWith('/stories')) {
      roots.addAll(['/stories', '/students/overview', '/students/rewards']);
    } else if (p.startsWith('/community')) {
      roots.add('/community');
    } else if (p.startsWith('/friends')) {
      roots.add('/friends');
    } else if (p.startsWith('/mobile-workspace')) {
      roots.add('/mobile-workspace');
    } else if (p.startsWith('/safety/blocks')) {
      roots.addAll(['/community', '/stories', '/friends', '/mobile-workspace']);
    } else if (p.startsWith('/content/notifications')) {
      roots.add('/content/notifications');
    } else if (p.startsWith('/consultations')) {
      roots.add('/consultations');
    } else if (p.startsWith('/accommodation')) {
      roots.add('/accommodation');
    } else {
      roots.addAll([
        '/students',
        '/applications',
        '/parents',
        '/university-portal',
        '/admin',
        '/partners',
        '/service-requests',
        '/scholarships'
      ]);
      if (p.startsWith('/admin/') ||
          p.startsWith('/universities') ||
          p.startsWith('/programs') ||
          p.startsWith('/content')) {
        roots.addAll([
          '/universities',
          '/programs',
          '/content',
          '/scholarships',
          '/accommodation/listings'
        ]);
      }
    }
    _snapshotVersion++;
    _inflight.clear();
    bool matches(String key) =>
        roots.any((root) => key.contains('$baseUrl$root'));
    _cache.removeWhere((key, _) => matches(key));
    _snapshots
        .removeWhere((key, _) => roots.any((root) => key.contains(':$root')));
    final privateScope = owner ?? _scopeForCurrentSession();
    for (final scope in {'public', if (privateScope != null) privateScope}) {
      // Queued before a following read, so a successful mutation cannot revive
      // an old disk snapshot when the caller immediately reloads its screen.
      unawaited(_store
          .invalidate(scope, matches)
          .catchError((Object _, StackTrace __) {}));
    }
    for (final root in roots) {
      _cacheChanges.add(root);
    }
  }

  String? _lastPrivateScope;
  String? _scopeForCurrentSession() =>
      activeCacheOwner?.call() ?? _lastPrivateScope;

  /// [idempotencyKey]: reuse the same key when the user re-sends the SAME
  /// draft after an uncertain failure, so a supporting server can de-duplicate.
  Future<dynamic> post(String path,
          {Map<String, dynamic>? body,
          String? token,
          String? idempotencyKey}) =>
      _request('POST', path,
          body: body, token: token, idempotencyKey: idempotencyKey);
  Future<dynamic> put(String path,
          {Map<String, dynamic>? body, String? token}) =>
      _request('PUT', path, body: body, token: token);
  Future<dynamic> patch(String path,
          {Map<String, dynamic>? body, String? token}) =>
      _request('PATCH', path, body: body, token: token);
  Future<dynamic> delete(String path, {String? token}) =>
      _request('DELETE', path, token: token);
  Future<dynamic> deleteWithBody(String path,
          {required Map<String, dynamic> body, String? token}) =>
      _request('DELETE', path, body: body, token: token);

  Future<List<int>> download(String path, {String? token}) async {
    final response = await _authorized(
        token,
        (credential) => _http.get(Uri.parse('$baseUrl$path'),
            headers: _headers(credential)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
    return response.bodyBytes;
  }

  /// Maps a file extension to the exact MIME type the backend's
  /// fileFilter allowlist expects (server/src/middleware/uploadMiddleware.js).
  /// CRITICAL: without this, http.MultipartFile defaults every upload to
  /// application/octet-stream, which the backend always rejects with
  /// "Unsupported file type" — this was the root cause of every upload
  /// failure across the app (documents, support tickets, payment proofs,
  /// agent uploads, content images).
  static MediaType _mimeTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'txt':
        return MediaType('text', 'plain');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'wav':
        return MediaType('audio', 'wav');
      case 'm4a':
        return MediaType('audio', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      default:
        return MediaType('application',
            'octet-stream'); // will still be rejected — matches an unsupported type on purpose
    }
  }

  /// Multipart upload (matches Multer's `upload.single("file")` on the
  /// backend). [fields] become additional form fields (e.g. `type` for a
  /// document's category) alongside the file itself.
  /// [onProgress] receives values 0.0–1.0 as bytes are sent.
  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fileFieldName = 'file',
    Map<String, String>? fields,
    String? token,
    void Function(double)? onProgress,
    UploadCancellation? cancellation,
  }) async {
    if (fileBytes.isEmpty) {
      throw const ApiException(400, 'الملف فارغ. اختر ملفًا آخر.');
    }
    final owner = _scope(token);
    final storyVideo = path == '/stories/video';
    if (fileBytes.length > (storyVideo ? 25 : 5) * 1024 * 1024) {
      throw ApiException(
          413,
          storyVideo
              ? 'اختر فيديو لا يتجاوز 25 ميجابايت.'
              : 'اختر ملفًا لا يتجاوز 5 ميجابايت.');
    }
    if (_mimeTypeFor(fileName).mimeType == 'application/octet-stream') {
      throw const ApiException(415, 'نوع الملف غير مدعوم.');
    }
    final response = await _authorized(token, (credential) async {
      if (cancellation?.cancelled == true) {
        throw const ApiException(499, 'تم إلغاء الرفع');
      }
      final request =
          _ProgressUpload('POST', Uri.parse('$baseUrl$path'), onProgress);
      if (credential != null) {
        request.headers['Authorization'] = 'Bearer $credential';
      }
      request.headers['X-Study-Birds-Client'] = 'mobile';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(fileFieldName, fileBytes,
          filename: fileName, contentType: _mimeTypeFor(fileName)));
      final client = createTransport();
      if (cancellation != null) cancellation._abort = client.close;
      try {
        final streamed = await client.send(request);
        return await http.Response.fromStream(streamed);
      } catch (swallowedError, swallowedStack) {
        ErrorReporter.swallowed(
            swallowedError, swallowedStack, 'core/network/api_client.dart:253');
        if (cancellation?.cancelled == true) {
          throw const ApiException(499, 'تم إلغاء الرفع');
        }
        rethrow;
      } finally {
        if (cancellation != null) cancellation._abort = null;
        client.close();
      }
    },
        mayChangeData: true,
        requestTimeout: Duration(seconds: storyVideo ? 120 : 30));
    return _decodeReporting(response, 'POST', path, owner: owner);
  }

  /// Decodes and records failures: every non-2xx leaves a breadcrumb, and
  /// server-side faults (5xx, unparseable 2xx) become de-duplicated Sentry events.
  dynamic _decodeReporting(http.Response response, String method, String path,
      {String? owner}) {
    try {
      final data = _decode(response);
      if (method != 'GET') {
        _invalidateMutation(path, owner: owner);
        if (path.startsWith('/safety/blocks')) clearCache();
        if (path.startsWith('/mobile-workspace/messages') ||
            path.startsWith('/mobile-workspace/conversations')) {
          _snapshotVersion++;
          _inflight.removeWhere(
              (key, value) => key.contains(':/mobile-workspace/conversations'));
          _snapshots.removeWhere(
              (key, value) => key.contains(':/mobile-workspace/conversations'));
        }
        if (path.startsWith('/stories')) {
          _snapshotVersion++;
          _inflight.removeWhere((key, value) => key.contains(':/stories'));
          _snapshots.removeWhere((key, value) => key.contains(':/stories'));
        }
      }
      return data;
    } on ApiException catch (e) {
      ErrorReporter.apiFailure(method, path, e.statusCode, error: e);
      rethrow;
    }
  }

  dynamic _decode(http.Response response) {
    final bodyText = response.body.isEmpty ? '{}' : response.body;
    late final dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(
          const FormatException('Invalid API JSON response'),
          swallowedStack,
          'api.decode');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException(502, AppError.unavailable);
      }
      decoded = const <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = (decoded is Map && decoded['message'] is String)
        ? decoded['message'] as String
        : '';
    final data =
        decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    throw ApiException(response.statusCode, message, data);
  }
}
