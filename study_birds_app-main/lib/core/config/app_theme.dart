import 'package:flutter/material.dart';

// Shared widgets live in lib/core/widgets/. They are re-exported here so
// existing `import 'app_theme.dart'` lines keep working unchanged.
export '../widgets/app_scaffold.dart';
export '../widgets/app_components.dart';
export '../widgets/state_widgets.dart';
export '../widgets/offline_banner_wrapper.dart';

/// Study Birds shared design system.
/// Navy primary, orange accents, white surfaces and consistent spacing.
class AppColors {
  static const Color navy = Color(0xFF011E46);
  static const Color navyLight = Color(0xFF16305F);
  static const Color orange = Color(0xFFFD6D04);
  static const Color orangeSoft = Color(0xFFFFEEDD);
  static const Color background = Color(0xFFF5F7FA);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E8EE);

  // Status colors (used for badges across the app)
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color neutral = Color(0xFF6B7280);
}

class AppRadius {
  static const double card = 16;
  static const double chip = 20;
  static const double button = 12;
}

class AppTheme {
  static ThemeData get light {
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button));
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.border));
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
          secondary: AppColors.orange,
          surface: Colors.white,
          error: AppColors.danger),
      appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 18,
              fontWeight: FontWeight.w700)),
      iconTheme: const IconThemeData(color: AppColors.navy, size: 22),
      dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 24),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
          errorBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.danger)),
          hintStyle: AppTextStyles.caption,
          labelStyle: AppTextStyles.body,
          prefixIconColor: AppColors.textSecondary,
          suffixIconColor: AppColors.textSecondary),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(48, 48),
              shape: shape,
              textStyle: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  fontSize: 14))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
              shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              minimumSize: const Size(48, 48),
              shape: shape,
              side: const BorderSide(color: AppColors.border))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.navy,
              minimumSize: const Size(48, 48))),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          shape: shape),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border))),
    );
  }
}

class AppIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const AppIconTile(this.icon, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: AppColors.orangeSoft, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppColors.orange, size: 23));
}

class AppTextStyles {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
  );
}

