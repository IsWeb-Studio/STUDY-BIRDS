import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Thrown by [ApiClient] for any non-2xx response. [message] is the
/// backend's own `{ message: "..." }` string when present, since the
/// Express error middleware always returns that shape.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Single place that knows the backend's base URL. When the Render URL
/// changes, this is the only line that needs editing.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://study-birds1.onrender.com/api');

  Future<String?> Function(String failedToken)? refreshSession;

  /// Supplied by AuthSession at call time so ApiClient itself has no
  /// circular dependency on the session — every authenticated call passes
  /// its own token explicitly.
  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'X-Study-Birds-Client': 'mobile',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _authorized(
      String? token, Future<http.Response> Function(String?) send) async {
    var response = await send(token).timeout(const Duration(seconds: 30));
    if (response.statusCode == 401 && token != null && refreshSession != null) {
      final replacement = await refreshSession!(token);
      if (replacement != null) response = await send(replacement).timeout(const Duration(seconds: 30));
    }
    return response;
  }

  Future<dynamic> _request(String method, String path, {String? token, Map<String, dynamic>? body}) async {
    final response = await _authorized(token, (credential) async {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers.addAll(_headers(credential));
      if (body != null) request.body = jsonEncode(body);
      final client = http.Client();
      try { return await http.Response.fromStream(await client.send(request)); }
      finally { client.close(); }
    });
    return _decode(response);
  }

  Future<dynamic> get(String path, {String? token}) => _request('GET', path, token: token);
  Future<dynamic> post(String path, {Map<String, dynamic>? body, String? token}) => _request('POST', path, body: body, token: token);
  Future<dynamic> put(String path, {Map<String, dynamic>? body, String? token}) => _request('PUT', path, body: body, token: token);
  Future<dynamic> patch(String path, {Map<String, dynamic>? body, String? token}) => _request('PATCH', path, body: body, token: token);
  Future<dynamic> delete(String path, {String? token}) => _request('DELETE', path, token: token);
  Future<dynamic> deleteWithBody(String path, {required Map<String, dynamic> body, String? token}) => _request('DELETE', path, body: body, token: token);

  Future<List<int>> download(String path, {String? token}) async {
    final response = await _authorized(token, (credential) => http.get(Uri.parse('$baseUrl$path'), headers: _headers(credential)));
    if (response.statusCode < 200 || response.statusCode >= 300) _decode(response);
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
      case 'pdf': return MediaType('application', 'pdf');
      case 'doc': return MediaType('application', 'msword');
      case 'docx': return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls': return MediaType('application', 'vnd.ms-excel');
      case 'xlsx': return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'ppt': return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx': return MediaType('application', 'vnd.openxmlformats-officedocument.presentationml.presentation');
      case 'txt': return MediaType('text', 'plain');
      case 'zip': return MediaType('application', 'zip');
      case 'jpg':
      case 'jpeg': return MediaType('image', 'jpeg');
      case 'png': return MediaType('image', 'png');
      case 'webp': return MediaType('image', 'webp');
      default: return MediaType('application', 'octet-stream'); // will still be rejected — matches an unsupported type on purpose
    }
  }

  /// Multipart upload (matches Multer's `upload.single("file")` on the
  /// backend). [fields] become additional form fields (e.g. `type` for a
  /// document's category) alongside the file itself.
  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fileFieldName = 'file',
    Map<String, String>? fields,
    String? token,
  }) async {
    final response = await _authorized(token, (credential) async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (credential != null) request.headers['Authorization'] = 'Bearer $credential';
      request.headers['X-Study-Birds-Client'] = 'mobile';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(fileFieldName, fileBytes, filename: fileName, contentType: _mimeTypeFor(fileName)));
      final client = http.Client();
      try { return await http.Response.fromStream(await client.send(request)); }
      finally { client.close(); }
    });
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final bodyText = response.body.isEmpty ? '{}' : response.body;
    late final dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } catch (_) {
      decoded = {'message': bodyText};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = (decoded is Map && decoded['message'] is String)
        ? decoded['message'] as String
        : 'Request failed (${response.statusCode})';
    throw ApiException(response.statusCode, message);
  }
}
