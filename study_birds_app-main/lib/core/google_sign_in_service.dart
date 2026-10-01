import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import 'auth_session.dart';
import 'analytics_service.dart';
import 'app_config.dart';

/// Native Google Sign-In using google_sign_in v7.
/// No Firebase — token is verified server-side via POST /auth/google.
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (AppConfig.googleWebClientId.isEmpty) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('[GoogleSignIn] init failed: $e');
    }
  }

  /// Returns true on success. Throws [ApiException] with a user-readable
  /// Arabic message on failure, or returns false if the user cancelled.
  Future<bool> signIn() async {
    if (!_initialized) await init();
    if (!_initialized) {
      throw ApiException(503, 'تسجيل الدخول عبر Google غير مهيأ بعد');
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw ApiException(401, 'تعذر الحصول على رمز المصادقة من Google');
      }
      final data = await ApiClient.instance.post(
        '/auth/google',
        body: {'credential': idToken},
      );
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;
      await AuthSession.instance.login(user, authToken: token, refreshToken: data['refreshToken'] as String?);
      AnalyticsService.instance.loginCompleted(user.role.name);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      if (kDebugMode) print('[GoogleSignIn] error: ${e.code} ${e.description}');
      throw ApiException(401, 'تعذر تسجيل الدخول عبر Google');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (kDebugMode) print('[GoogleSignIn] unexpected: $e');
      throw ApiException(500, 'حدث خطأ غير متوقع');
    }
  }

  Future<void> signOut() async {
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
  }

  bool get isAvailable =>
      _initialized && AppConfig.googleWebClientId.isNotEmpty;
}
