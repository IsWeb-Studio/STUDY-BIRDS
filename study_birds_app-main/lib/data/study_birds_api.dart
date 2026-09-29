import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// One session and API origin for all native application screens.
class StudyBirdsApi extends ChangeNotifier {
  StudyBirdsApi({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.trim();
    }
    if (kDebugMode) {
      // Android Emulator reaches the development computer through this alias.
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:5000/api'
          : 'http://localhost:5000/api';
    }
    return 'https://study-birds-api.onrender.com/api';
  }

  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _token;
  Map<String, dynamic>? user;
  bool needsProfileSetup = false;
  void finishProfileSetup() {
    needsProfileSetup = false;
    notifyListeners();
  }

  bool get authenticated => _token != null && user != null;
  String get role => user?['role']?.toString() ?? '';
  Future<bool> hasSeenIntroduction() async =>
      await _storage.read(key: 'study_birds_intro') == 'done';
  Future<void> completeIntroduction() =>
      _storage.write(key: 'study_birds_intro', value: 'done');

  Future<void> restore() async {
    _token = await _storage.read(key: 'study_birds_token');
    if (_token == null) return;
    final response = await request('GET', '/auth/me');
    user = Map<String, dynamic>.from(response['user']);
    if (!['student', 'partner', 'parent', 'university', 'employee']
        .contains(role)) {
      await logout();
      return;
    }
    notifyListeners();
  }

  Future<void> authenticate(String email, String password,
      {String? name, String? accountRole, String? twoFactorCode}) async {
    final response = await request(
        'POST', name == null ? '/auth/login' : '/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          if (twoFactorCode != null) 'twoFactorCode': twoFactorCode,
          if (name != null) 'name': name.trim(),
          if (name != null && accountRole != null) 'role': accountRole,
        });
    final nextUser = Map<String, dynamic>.from(response['user']);
    if (!['student', 'partner', 'parent', 'university', 'employee']
        .contains(nextUser['role'])) {
      throw const ApiException(
          'هذا الحساب إداري. استخدم لوحة التحكم في الموقع.');
    }
    if (accountRole != null && nextUser['role'] != accountRole) {
      throw const ApiException(
          'نوع الحساب المختار لا يطابق حسابك. اختر النوع الصحيح.');
    }
    await _storage.write(key: 'study_birds_token', value: response['token']);
    _token = response['token'];
    user = nextUser;
    needsProfileSetup = name != null && nextUser['role'] == 'student';
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    notifyListeners();
    await _storage.delete(key: 'study_birds_token');
  }

  /// Permanently deletes the authenticated account.
  /// Requires [password] so a stolen unlocked phone cannot wipe the account
  /// silently. On success the local session is cleared. On a 401 (wrong
  /// password) the session is preserved and an [ApiException] is thrown so
  /// the UI can show the error without logging the user out.
  Future<void> deleteAccount(String password) async {
    if (password.isEmpty) {
      throw const ApiException('كلمة المرور مطلوبة.');
    }
    final req = http.Request('DELETE', uri('/auth/account'));
    req.headers['Accept'] = 'application/json';
    req.headers['Content-Type'] = 'application/json';
    req.headers['X-Study-Birds-Client'] = 'mobile';
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.body = jsonEncode({'password': password});

    // Bypasses the _send() 401→auto-logout guard so a wrong password does not
    // silently end the session. We handle each outcome explicitly here.
    final response = await _client
        .send(req)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 45));

    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
          'استجابة غير صالحة من الخادم (${response.statusCode}).', response.statusCode);
    }

    if (response.statusCode == 401) {
      throw ApiException(
        data is Map
            ? (data['message'] ?? 'كلمة المرور غير صحيحة.').toString()
            : 'كلمة المرور غير صحيحة.',
        401,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data is Map ? (data['message'] ?? 'تعذر تنفيذ الطلب').toString() : 'تعذر تنفيذ الطلب',
        response.statusCode,
      );
    }

    await logout();
  }

  Uri uri(String path) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
  Future<dynamic> request(String method, String path, {Object? body}) async {
    final request = http.Request(method, uri(path));
    request.headers['Accept'] = 'application/json';
    request.headers['X-Study-Birds-Client'] = 'mobile';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _send(request);
  }

  Future<dynamic> upload(
      String path, PlatformFile file, Map<String, String> fields) async {
    if (file.size > 5 * 1024 * 1024) {
      throw const ApiException('الحد الأقصى للملف 5 ميجابايت.');
    }
    if (file.bytes == null) {
      throw const ApiException('تعذر قراءة الملف. اختر الملف مجدداً.');
    }
    final request = http.MultipartRequest('POST', uri(path));
    request.headers['X-Study-Birds-Client'] = 'mobile';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields.addAll(fields);
    const types = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    };
    final type = types[file.extension?.toLowerCase()];
    if (type == null) throw const ApiException('نوع الملف غير مدعوم');
    request.files.add(http.MultipartFile.fromBytes('file', file.bytes!,
        filename: file.name, contentType: MediaType.parse(type)));
    return _send(request);
  }

  Future<dynamic> _send(http.BaseRequest request) async {
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 45));
      dynamic data;
      try {
        data = response.body.isEmpty
            ? null
            : jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw ApiException(
            'استجابة غير صالحة من الخادم (${response.statusCode}).',
            response.statusCode);
      }
      if (response.statusCode == 401 && _token != null) await logout();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
            data is Map
                ? (data['message'] ?? 'تعذر تنفيذ الطلب').toString()
                : 'تعذر تنفيذ الطلب',
            response.statusCode);
      }
      return data;
    } on TimeoutException {
      throw const ApiException('انتهت مهلة الاتصال. حاول مرة أخرى.');
    } on http.ClientException {
      throw const ApiException(
          'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.');
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
