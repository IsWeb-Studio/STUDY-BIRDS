import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../network/api_client.dart';
import '../utils/json_safe.dart';
import 'auth_session.dart';

class AppleSignInService {
  AppleSignInService._();
  static final instance = AppleSignInService._();
  String? _challenge;

  Future<bool> signIn() async {
    _challenge = null;
    try {
      if (!await SignInWithApple.isAvailable()) {
        throw const ApiException(
            503, 'تسجيل الدخول بـApple غير متاح على هذا الجهاز.');
      }
      final options = Json.map(
          await ApiClient.instance.post('/identity/apple/native/options'));
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: options['nonce'] as String,
        state: options['challengeId'] as String,
      );
      if (credential.state != options['challengeId'] ||
          credential.identityToken == null) {
        throw const ApiException(
            401, 'تعذر التحقق من حساب Apple. حاول مجددًا.');
      }
      final data =
          await ApiClient.instance.post('/identity/apple/native/verify', body: {
        'challengeId': options['challengeId'],
        'identityToken': credential.identityToken,
        'name': [credential.givenName, credential.familyName]
            .whereType<String>()
            .join(' '),
      });
      await _finish(Json.map(data));
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      throw const ApiException(401, 'تعذر إكمال الدخول بـApple. حاول مجددًا.');
    } on ApiException catch (e) {
      if (e.statusCode == 428) _challenge = e.data['challengeId'] as String?;
      if (e.statusCode == 409) {
        throw const ApiException(409,
            'هذا البريد مرتبط بحساب موجود. ادخل بالطريقة الأصلية لهذا الحساب.');
      }
      rethrow;
    }
  }

  Future<void> confirmEmail(String code) async {
    if (_challenge == null) {
      throw const ApiException(401, 'أعد تسجيل الدخول بـApple.');
    }
    final data = await ApiClient.instance.post('/identity/apple/native/confirm',
        body: {'challengeId': _challenge, 'emailCode': code});
    await _finish(Json.map(data));
  }

  Future<void> resendEmailCode() async {
    if (_challenge == null) {
      throw const ApiException(401, 'أعد تسجيل الدخول بـApple.');
    }
    await ApiClient.instance.post('/identity/apple/native/resend',
        body: {'challengeId': _challenge});
  }

  Future<void> _finish(Map<String, dynamic> data) async {
    await AuthSession.instance.login(AuthUser.fromJson(Json.map(data['user'])),
        authToken: data['token'] as String,
        refreshToken: data['refreshToken'] as String?);
    _challenge = null;
  }
}
