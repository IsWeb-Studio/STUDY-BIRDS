import 'package:flutter/widgets.dart';
import '../core/services/locale_controller.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.tryAgain`. Falls back to Arabic when a widget is mounted
/// without the localization delegates (some tests and tiny preview apps), so a
/// missing delegate can never crash the UI.
extension AppL10n on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('ar'));
}

/// Reading direction of the chosen app language (Arabic is the default and
/// stays right-to-left unless the user picked English).
TextDirection get appTextDirection =>
    LocaleController.instance.locale.languageCode == 'en'
        ? TextDirection.ltr
        : TextDirection.rtl;
