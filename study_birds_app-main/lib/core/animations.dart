import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Global page-transition theme: slides the incoming page in from the
/// direction that matches the CURRENT text direction (RTL for Arabic — new
/// pages slide in from the left, not the right, matching how the eye
/// naturally moves in RTL layouts). Set once in MaterialApp.theme and every
/// `Navigator.push(MaterialPageRoute(...))` in the app picks it up
/// automatically — no per-screen changes needed.
class RTLAwarePageTransitionsBuilder extends PageTransitionsBuilder {
  const RTLAwarePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final beginOffset = isRTL ? const Offset(-1, 0) : const Offset(1, 0);

    final slide = Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    final outSlide = Tween<Offset>(begin: Offset.zero, end: beginOffset * -0.25).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic),
    );

    return SlideTransition(
      position: outSlide,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Applies [RTLAwarePageTransitionsBuilder] to every platform so behavior is
/// identical on Android/iOS/etc. Plug into ThemeData as:
/// `pageTransitionsTheme: appPageTransitionsTheme`
final appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    for (final platform in TargetPlatform.values) platform: const RTLAwarePageTransitionsBuilder(),
  },
);

/// Wraps any button/widget with a slow, subtle breathing pulse (scale
/// 1.0 → 1.04 → 1.0) to draw the eye — used for the Onboarding "Next"
/// button and the Splash logo.
class BreathingPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double maxScale;
  const BreathingPulse({super.key, required this.child, this.duration = const Duration(milliseconds: 1600), this.maxScale = 1.04});

  @override
  State<BreathingPulse> createState() => _BreathingPulseState();
}

class _BreathingPulseState extends State<BreathingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: widget.maxScale).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// Wraps any tappable widget with a quick scale-down-then-spring-back
/// bounce on tap — used for Account Type selection cards and similar
/// choice cards. Calls [onTap] on release.
class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double downScale;
  const BounceTap({super.key, required this.child, this.onTap, this.downScale = 0.94});

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120), lowerBound: 0, upperBound: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1 - (_controller.value * (1 - widget.downScale));
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// Animates a progress value (0..1) smoothly from 0 to [value] whenever the
/// widget first appears or [value] changes — used for the Journey Tracker
/// ring/line and any other progress indicator that should "fill up" rather
/// than snap to its final state.
class AnimatedProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Widget Function(double animatedPercent)? centerBuilder;

  const AnimatedProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 5,
    this.centerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: animatedValue,
                strokeWidth: strokeWidth,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.orange),
              ),
              if (centerBuilder != null) centerBuilder!(animatedValue),
            ],
          ),
        );
      },
    );
  }
}

/// Animates a horizontal/vertical progress line filling from 0 to [value]
/// — a lightweight CustomPainter-based line, used behind Journey Tracker
/// stage connectors instead of a flat static color.
class AnimatedProgressLine extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final Color backgroundColor;
  final double thickness;
  final Axis axis;

  const AnimatedProgressLine({
    super.key,
    required this.value,
    this.color = AppColors.success,
    this.backgroundColor = AppColors.border,
    this.thickness = 2,
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, animatedValue, _) {
        return CustomPaint(
          painter: _ProgressLinePainter(animatedValue, color, backgroundColor, thickness, axis),
          child: axis == Axis.vertical ? SizedBox(width: thickness) : SizedBox(height: thickness),
        );
      },
    );
  }
}

class _ProgressLinePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double thickness;
  final Axis axis;
  _ProgressLinePainter(this.value, this.color, this.backgroundColor, this.thickness, this.axis);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor..strokeWidth = thickness;
    final fgPaint = Paint()..color = color..strokeWidth = thickness;
    if (axis == Axis.vertical) {
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), bgPaint);
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height * value), fgPaint);
    } else {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), bgPaint);
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width * value, size.height / 2), fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLinePainter oldDelegate) => oldDelegate.value != value;
}

/// Shows a bottom sheet that slides up over a smoothly-animated blurred
/// backdrop (BackdropFilter), instead of the flat dim scrim. Use this for
/// Consultation Booking and similar flows instead of `showModalBottomSheet`
/// directly.
Future<T?> showAnimatedBottomSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: curved,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6 * curved.value, sigmaY: 6 * curved.value),
                child: Container(color: Colors.black.withValues(alpha: 0.25 * curved.value)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: builder(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// A checkmark that pops in with a spring/elastic curve — used for success
/// confirmations (e.g. "Appointment Confirmed"). Call [showSuccessModal] to
/// present it as a small centered overlay.
class SuccessCheckAnimation extends StatefulWidget {
  final String title;
  final String? message;
  const SuccessCheckAnimation({super.key, required this.title, this.message});

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4, curve: Curves.easeOut));

    return FadeTransition(
      opacity: fade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: scale,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
          if (widget.message != null) ...[
            const SizedBox(height: 6),
            Text(widget.message!, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

Future<void> showSuccessModal(BuildContext context, {required String title, String? message}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, a1, a2) => Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: SuccessCheckAnimation(title: title, message: message),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
