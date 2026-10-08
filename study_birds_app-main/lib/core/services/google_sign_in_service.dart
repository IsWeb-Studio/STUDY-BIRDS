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
  // Stored during Google 2FA flow — holds the idToken between the initial
  // sign-in attempt (which returned 428) and the 2FA confirmation call.
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
    if (!_initialized) await init();
    if (!_initialized) {
      // Surface the real init error so developers can diagnose the issue
      final reason = _initError ?? 'لم يتم تهيئة Google Sign-In';
      if (kDebugMode) print('[GoogleSignIn] not available, init error: $reason');
      throw ApiException(503, 'تسجيل الدخول عبر Google غير متاح على هذا الجهاز.\n($reason)');
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
      final detail = e.description != null ? '\n(${e.description})' : '';
      throw ApiException(401, 'تعذر تسجيل الدخول عبر Google$detail');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (kDebugMode) print('[GoogleSignIn] unexpected: $e');
      throw ApiException(500, 'حدث خطأ أثناء تسجيل الدخول عبر Google\n($e)');
    }
  }

  Future<void> _loginWithCredential(String idToken, {String? twoFactorCode}) async {
    final body = <String, dynamic>{'credential': idToken};
    if (twoFactorCode != null) body['twoFactorCode'] = twoFactorCode;
    try {
      final data = await ApiClient.instance.post('/auth/google', body: body);
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;
      await AuthSession.instance.login(user, authToken: token, refreshToken: data['refreshToken'] as String?);
      AnalyticsService.instance.loginCompleted(user.role.name);
      _pendingIdToken = null;
    } on ApiException catch (e) {
      if (e.statusCode == 428) {
        // 2FA required — save idToken so caller can re-confirm with a code
        _pendingIdToken = idToken;
      }
      rethrow;
    }
  }

  /// Call after receiving ApiException(428) from [signIn].
  /// Completes sign-in using the 2FA code the user entered.
  Future<void> confirmTwoFactor(String code) async {
    final idToken = _pendingIdToken;
    if (idToken == null) throw const ApiException(400, 'انتهت صلاحية جلسة Google. أعد المحاولة.');
    await _loginWithCredential(idToken, twoFactorCode: code);
  }

  Future<void> signOut() async {
    _pendingIdToken = null;
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
  }

  bool get isAvailable =>
      _initialized && AppConfig.googleWebClientId.isNotEmpty;
}
