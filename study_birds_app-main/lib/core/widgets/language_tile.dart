import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../config/app_theme.dart';
import '../services/locale_controller.dart';

/// Arabic / English switch for the Settings screen.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppCard(
        child: Row(children: [
          const Icon(Icons.language_rounded, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(child: Text(context.l10n.language, style: AppTextStyles.cardTitle)),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'ar', label: Text(context.l10n.languageArabic)),
              ButtonSegment(value: 'en', label: Text(context.l10n.languageEnglish)),
            ],
            selected: {controller.locale.languageCode},
            onSelectionChanged: (s) => controller.setLocale(Locale(s.first)),
          ),
        ]),
      ),
    );
  }
}
