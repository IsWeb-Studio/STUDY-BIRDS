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
  ApiClient._() : _fixed = null;

  /// Test seam: lets tests inject a fake transport.
  ApiClient.forTesting(http.Client client) : _fixed = client;
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
  /// Cleared on logout. TTL = 3 minutes.
  final _cache = <String, ({DateTime at, dynamic data})>{};
  static const _cacheTtl = Duration(minutes: 3);

  void clearCache() => _cache.clear();

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
        if (replacement != null)
          response = await send(replacement).timeout(requestTimeout);
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
    final mutating = method != 'GET';
    final operationId = mutating ? (idempotencyKey ?? _newOperationId()) : null;
    final response = await _authorized(token, (credential) async {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers.addAll(_headers(credential));
      if (operationId != null) request.headers['Idempotency-Key'] = operationId;
      if (body != null) request.body = jsonEncode(body);
      return await http.Response.fromStream(await _http.send(request));
    }, mayChangeData: mutating && !path.startsWith('/auth/'));
    return _decodeReporting(response, method, path);
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

  Future<dynamic> get(String path, {String? token, bool cached = true}) async {
    // The in-memory cache is process-wide; under `flutter test` it would leak
    // one test's responses into the next.
    if (_perCallClient) cached = false;
    final key = '${token ?? ''}:$path';
    if (cached) {
      final hit = _cache[key];
      if (hit != null && DateTime.now().difference(hit.at) < _cacheTtl) {
        return hit.data;
      }
    }
    final pending = _inflight[key];
    if (pending != null) return pending;
    final future = _getWithRetry(path, token);
    _inflight[key] = future;
    try {
      final data = await future;
      if (cached) _cache[key] = (at: DateTime.now(), data: data);
      return data;
    } finally {
      _inflight.remove(key);
    }
  }

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
    if (response.statusCode < 200 || response.statusCode >= 300)
      _decode(response);
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
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType('application',
            'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType('application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'ppt':
        return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx':
        return MediaType('application',
            'vnd.openxmlformats-officedocument.presentationml.presentation');
      case 'txt':
        return MediaType('text', 'plain');
      case 'zip':
        return MediaType('application', 'zip');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'mp4':
        return MediaType('video', 'mp4');
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
    if (fileBytes.isEmpty)
      throw const ApiException(400, 'الملف فارغ. اختر ملفًا آخر.');
    final storyVideo = path == '/stories/video';
    if (fileBytes.length > (storyVideo ? 25 : 5) * 1024 * 1024) {
      throw ApiException(
          413,
          storyVideo
              ? 'اختر فيديو لا يتجاوز 25 ميجابايت.'
              : 'اختر ملفًا لا يتجاوز 5 ميجابايت.');
    }
    if (_mimeTypeFor(fileName).mimeType == 'application/octet-stream')
      throw const ApiException(415, 'نوع الملف غير مدعوم.');
    final response = await _authorized(token, (credential) async {
      if (cancellation?.cancelled == true)
        throw const ApiException(499, 'تم إلغاء الرفع');
      final request =
          _ProgressUpload('POST', Uri.parse('$baseUrl$path'), onProgress);
      if (credential != null)
        request.headers['Authorization'] = 'Bearer $credential';
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
        if (cancellation?.cancelled == true)
          throw const ApiException(499, 'تم إلغاء الرفع');
        rethrow;
      } finally {
        if (cancellation != null) cancellation._abort = null;
        client.close();
      }
    },
        mayChangeData: true,
        requestTimeout: Duration(seconds: storyVideo ? 120 : 30));
    return _decodeReporting(response, 'POST', path);
  }

  /// Decodes and records failures: every non-2xx leaves a breadcrumb, and
  /// server-side faults (5xx, unparseable 2xx) become de-duplicated Sentry events.
  dynamic _decodeReporting(http.Response response, String method, String path) {
    try {
      return _decode(response);
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
          swallowedError, swallowedStack, 'core/network/api_client.dart:280');
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
