// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Study Birds';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabJourney => 'الرحلة';

  @override
  String get tabExplore => 'استكشاف';

  @override
  String get tabServices => 'الخدمات';

  @override
  String get tabProfile => 'حسابي';

  @override
  String get offlineTitle => 'لا يوجد اتصال بالإنترنت';

  @override
  String get offlineMessage =>
      'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.';

  @override
  String get errorGenericTitle => 'نحتاج لحظة لإكمال طلبك';

  @override
  String get tryAgain => 'إعادة المحاولة';

  @override
  String get bannerOffline =>
      'لا يوجد اتصال بالإنترنت — تُعرض آخر بيانات محفوظة';

  @override
  String get bannerUnreachable =>
      'متصل بالشبكة لكن تعذّر الوصول إلى الخدمة — نحاول إعادة الاتصال';

  @override
  String get bannerUnstable => 'الاتصال غير مستقر — نحاول إعادة الاتصال';

  @override
  String get bannerRestored => 'عاد الاتصال بالإنترنت';

  @override
  String get updateTitle => 'تحديث مطلوب';

  @override
  String get updateNow => 'تحديث الآن';

  @override
  String get updateDefaultMessage =>
      'يتوفر إصدار أحدث من التطبيق ولم يعد هذا الإصدار مدعومًا. حدّث التطبيق للمتابعة.';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';
}
