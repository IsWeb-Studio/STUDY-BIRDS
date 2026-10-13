import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app language.
///
/// Arabic is the default. English is fully wired (ARB files, delegates, text
/// direction) but only offered to users when the build sets
/// `--dart-define=ENABLE_EN=true`, because most screens still contain
/// hard-coded Arabic text that has not been moved into the ARB files yet. Turn
/// the flag on once the remaining screens are migrated.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _key = 'app_locale';
  static const englishEnabled = bool.fromEnvironment('ENABLE_EN', defaultValue: false);
  static const supported = [Locale('ar'), Locale('en')];

  Locale _locale = const Locale('ar');
  Locale get locale => _locale;

  Future<void> load() async {
    if (!englishEnabled) return;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      final next = supported.where((l) => l.languageCode == saved);
      if (next.isNotEmpty && next.first != _locale) {
        _locale = next.first;
        notifyListeners();
      }
    } catch (_) {
      // Keep the default.
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!englishEnabled && locale.languageCode != 'ar') return;
    if (!supported.contains(locale) || locale == _locale) return;
    _locale = locale;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, locale.languageCode);
    } catch (_) {}
  }
}
