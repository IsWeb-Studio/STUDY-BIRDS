import 'dart:convert';

class PasswordPolicy {
  static final upper = RegExp(r'\p{Lu}', unicode: true);
  static final lower = RegExp(r'[\p{Ll}\p{Lo}]', unicode: true);
  static final number = RegExp(r'\p{N}', unicode: true);
  static final symbol = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static int kinds(String value) => [upper, lower, number, symbol]
      .where((pattern) => pattern.hasMatch(value))
      .length;
  static bool isCommon(String value) => RegExp(
          r'^(password|qwerty|welcome|letmein|admin|studybirds|abcdefgh|12345678|87654321)\d*$',
          caseSensitive: false)
      .hasMatch(value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''));
  static String? validate(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'أدخل كلمة المرور';
    if (password.length < 8) return 'استخدم 8 أحرف على الأقل';
    if (utf8.encode(password).length > 72)
      return 'كلمة المرور طويلة جدًا. استخدم واحدة أقصر.';
    if (isCommon(password) || password.runes.toSet().length < 4) {
      return 'هذه الكلمة سهلة التخمين. اختر كلمة أقل شيوعًا وتجنب التكرار.';
    }
    if (kinds(password) < 3)
      return 'اخلط 3 أنواع على الأقل: أحرف كبيرة، أحرف صغيرة أو عربية، أرقام، رموز.';
    return null;
  }
}
