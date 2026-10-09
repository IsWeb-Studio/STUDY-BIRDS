import '../utils/app_error.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../screens/ai/birds_ai_screen.dart';

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

/// Standard scaffold wrapper: navy app bar, RTL, background color.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final bool showBackButton;
  final bool hideAiButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
    this.showBackButton = true,
    this.hideAiButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: showBackButton,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: actions,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              OfflineBannerWrapper(child: body),
              if (!hideAiButton)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _AiFloatingButton(),
                ),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

class _AiFloatingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const BirdsAiScreen(),
              fullscreenDialog: true)),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.navy,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: const Icon(Icons.auto_awesome_rounded,
            color: AppColors.orange, size: 24),
      ),
    );
  }
}

/// Reusable white rounded card container.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
  }
}

/// Drop-in replacement for Image.network with persistent disk caching.
/// Avoids re-downloading the same image on every widget rebuild.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(
        color: AppColors.border,
        width: width,
        height: height,
      ),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          Container(
            color: AppColors.border,
            width: width,
            height: height,
            child: const Icon(Icons.image_not_supported_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
    );
  }
}

/// Small colored status/badge pill. Pass one of AppColors' status colors.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary navy filled button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5))),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Skeleton loading screen — replaces circular spinners with shimmer cards.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: i == 0 && message != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(height: 14, width: 140),
                ),
                const SkeletonCard(),
              ])
            : const SkeletonCard(),
      ),
    );
  }
}

/// Skeleton shimmer placeholder — for loading states that need layout fidelity.
/// Animates opacity 0.3→0.7→0.3 to communicate "loading in progress".
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonBox(
      {super.key,
      this.width = double.infinity,
      this.height = 16,
      this.borderRadius = 8});
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.65).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        ),
      );
}

/// A skeleton card that mimics an AppCard with two text lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(height: 14, width: 160),
            SizedBox(height: 10),
            SkeletonBox(height: 12),
            SizedBox(height: 6),
            SkeletonBox(height: 12, width: 120),
          ],
        ),
      );
}

/// Standard error state — never a blank/broken screen, per spec point 69.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState(
      {super.key,
      this.message = 'حدث خطأ غير متوقع، حاول مرة أخرى.',
      this.onRetry});

  @override
  Widget build(BuildContext context) {
    final text = AppError.safeText(message);
    final offline = text.contains('اتصال') || text.contains('إنترنت');
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .04), blurRadius: 24, offset: const Offset(0, 8))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: AppColors.orangeSoft, shape: BoxShape.circle),
              child: Icon(offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded, size: 34, color: AppColors.orange)),
            const SizedBox(height: 20),
            Text(offline ? 'لنعد الاتصال' : 'نحتاج لحظة لإكمال طلبك', style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(text, style: AppTextStyles.caption.copyWith(fontSize: 14, height: 1.8), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              PrimaryButton(label: 'إعادة المحاولة', onPressed: onRetry, expand: false, icon: Icons.refresh_rounded),
            ],
          ]),
        ),
      ),
    ));
  }
}

/// Persistent banner shown when the device is offline. Per spec point 67:
/// cached data can still show, but sensitive actions should be blocked
/// elsewhere in the screen while this banner is visible.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.neutral,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text('لا يوجد اتصال بالإنترنت — يتم عرض آخر بيانات محفوظة',
              style: TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Standard confirmation dialog for sensitive actions (submit application,
/// delete, cancel appointment, confirm payment, replace document — spec point 70).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool danger = false,
  bool scrollable = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        scrollable: scrollable,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(title, style: AppTextStyles.cardTitle),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: danger ? AppColors.danger : AppColors.orange,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
            if (ctaLabel != null) ...[
              const SizedBox(height: 16),
              PrimaryButton(label: ctaLabel!, onPressed: onCta, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps a [child] and shows a persistent banner at the top when the device
/// has no internet connection. Listens to connectivity changes in real time.
///
/// PRD بند 69 — Offline Banner.
class OfflineBannerWrapper extends StatefulWidget {
  final Widget child;
  const OfflineBannerWrapper({super.key, required this.child});

  @override
  State<OfflineBannerWrapper> createState() => _OfflineBannerWrapperState();
}

class _OfflineBannerWrapperState extends State<OfflineBannerWrapper> {
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_update);
    _sub = Connectivity().onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return widget.child;
    return Column(
      children: [
        Material(
          color: AppColors.warning,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'لا يوجد اتصال بالإنترنت — تعرض البيانات المحفوظة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Password strength indicator bar. Shows nothing when [password] is empty.
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  static int _score(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final score = _score(password);
    final color = score <= 1
        ? AppColors.danger
        : score <= 3
            ? AppColors.warning
            : AppColors.success;
    final label = score <= 1 ? 'ضعيفة' : score <= 3 ? 'متوسطة' : 'قوية';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'قوة كلمة المرور: $label',
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
