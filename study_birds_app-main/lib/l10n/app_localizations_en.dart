// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Study Birds';

  @override
  String get tabHome => 'Home';

  @override
  String get tabJourney => 'Journey';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabServices => 'Services';

  @override
  String get tabProfile => 'Account';

  @override
  String get offlineTitle => 'No Internet Connection';

  @override
  String get offlineMessage =>
      'Please check your internet connection and try again.';

  @override
  String get errorGenericTitle => 'We need a moment to finish your request';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get bannerOffline =>
      'No internet connection — showing the last saved data';

  @override
  String get bannerUnreachable =>
      'Connected, but the service can\'t be reached — retrying';

  @override
  String get bannerUnstable => 'Your connection is unstable — retrying';

  @override
  String get bannerRestored => 'You\'re back online';

  @override
  String get updateTitle => 'Update required';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateDefaultMessage =>
      'A newer version of the app is available and this version is no longer supported. Please update to continue.';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';
}
