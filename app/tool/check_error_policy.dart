import 'dart:async';
import '../lib/core/utils/app_error.dart';

void expect(bool condition, String name) {
  if (!condition) throw StateError('Failed: $name');
}

void main() {
  expect(AppError.message(TimeoutException('secret')) == AppError.timeout,
      'timeout');
  expect(AppError.message(StateError('secret token')) == AppError.unexpected,
      'unknown exception');
  expect(AppError.response(401, 'Invalid credentials').contains('كلمة المرور'),
      'credentials');
  expect(AppError.response(429, '').contains('انتظر'), 'rate limit');
  expect(AppError.response(413, '').contains('حجم'), 'upload size');
  expect(AppError.response(428, '').contains('التحقق'), 'verification');
  expect(AppError.response(0, '') == AppError.connection, 'network');
  for (final status in [
    400,
    401,
    403,
    404,
    409,
    413,
    415,
    422,
    428,
    429,
    500,
    502,
    503,
    504
  ]) {
    for (final raw in [
      'MongoServerError secret',
      '<html>bad</html>',
      'استجابة 500',
      'خطأ في https://secret.example',
      'تفاصيل E11000'
    ]) {
      final message = AppError.response(status, raw);
      expect(
          !RegExp(r'secret|Mongo|html|E11000|\b[45]\d\d\b').hasMatch(message),
          'safe response $status');
    }
  }
  expect(
      AppError.response(400, 'رمز غير صحيح أو منتهي الصلاحية') ==
          'رمز غير صحيح أو منتهي الصلاحية',
      'Arabic reason');
  expect(
      AppError.safeText('اختر ملفًا لا يتجاوز 5 ميجابايت.')
          .contains('5 ميجابايت'),
      'helpful size limit');
  print('Error policy checks passed.');
}
