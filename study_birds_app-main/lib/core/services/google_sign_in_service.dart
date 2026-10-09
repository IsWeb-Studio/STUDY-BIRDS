import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';
import '../network/api_client.dart';
import 'auth_session.dart';
import 'analytics_service.dart';
import '../config/app_config.dart';

/// Native Google Sign-In using google_sign_in v7.
/// No Firebase — token is verified server-side via POST /auth/google.
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  bool _initialized = false;
  Future<void>? _initFuture;
  String? _initError;
  String? _pendingIdToken;

  Future<void> init() async {
    if (_initialized) return;
    if (AppConfig.googleWebClientId.isEmpty) return;
    // Deduplicate concurrent init calls — only one initialize() runs at a time.
    _initFuture ??= _runInit().whenComplete(() => _initFuture = null);
    await _initFuture!;
  }

  Future<void> _runInit() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      _initialized = true;
      _initError = null;
    } catch (e) {
      _initError = e.toString();
      if (kDebugMode) print('[GoogleSignIn] init failed: $e');
    }
  }

  /// Returns true on success. Throws [ApiException] with a user-readable
  /// Arabic message on failure, or returns false if the user cancelled.
  Future<bool> signIn() async {
    _pendingIdToken = null;
    if (!_initialized) await init();
    if (!_initialized) {
      // Surface the real init error so developers can diagnose the issue
      final reason = _initError ?? 'لم يتم تهيئة Google Sign-In';
      if (kDebugMode) print('[GoogleSignIn] not available, init error: $reason');
      throw const ApiException(503, 'تسجيل الدخول عبر Google غير متاح حاليًا. حاول لاحقًا.');
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const ApiException(401, 'تعذر الحصول على رمز المصادقة من Google');
      }
      await _loginWithCredential(idToken);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      if (kDebugMode) print('[GoogleSignIn] error: ${e.code} ${e.description}');
      throw const ApiException(401, 'تعذّر تسجيل الدخول عبر Google. أعد اختيار الحساب وحاول مجددًا.');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (kDebugMode) print('[GoogleSignIn] unexpected: $e');
      throw const ApiException(500, 'تعذّر تسجيل الدخول عبر Google. حاول مجددًا بعد قليل.');
    }
  }

  Future<void> _loginWithCredential(String idToken, {String? emailCode}) async {
    final Map<String, dynamic> data;
    try {
      data = await ApiClient.instance.post('/auth/google', body: {
        'credential': idToken,
        if (emailCode != null) 'emailCode': emailCode,
        // Older deployed servers read the Google challenge as twoFactorCode.
        if (emailCode != null) 'twoFactorCode': emailCode,
      });
    } on ApiException catch (e) {
      if (e.statusCode == 428) _pendingIdToken = idToken;
      rethrow;
    }
    final user = AuthUser.fromGoogleJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    await AuthSession.instance.login(user,
        requireGooglePasswordSetup: !user.hasPassword,
        authToken: token, refreshToken: data['refreshToken'] as String?);
    AnalyticsService.instance.loginCompleted(user.role.name);
    _pendingIdToken = null;
  }

  Future<void> confirmEmail(String code) async {
    final idToken = _pendingIdToken;
    if (idToken == null) {
      throw const ApiException(400, 'انتهت جلسة Google. أعد تسجيل الدخول.');
    }
    await _loginWithCredential(idToken, emailCode: code);
  }

  Future<void> resendEmailCode() async {
    final idToken = _pendingIdToken;
    if (idToken == null) {
      throw const ApiException(400, 'انتهت جلسة Google. أعد تسجيل الدخول.');
    }
    try {
      await _loginWithCredential(idToken);
    } on ApiException catch (e) {
      if (e.statusCode != 428) rethrow;
    }
  }

  Future<void> signOut() async {
    _pendingIdToken = null;
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
  }

  bool get isAvailable =>
      _initialized && AppConfig.googleWebClientId.isNotEmpty;
}
