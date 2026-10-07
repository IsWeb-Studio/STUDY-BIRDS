import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/animations.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Three dots — each offset by 180ms
  late final List<AnimationController> _dotCtrls;
  late final List<Animation<double>> _dotScales;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _logoScale = Tween<double>(begin: 0.78, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade =
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoCtrl.forward();

    // Staggered bouncing dots
    _dotCtrls = List.generate(
      3,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500)),
    );
    _dotScales = _dotCtrls
        .map((c) => Tween<double>(begin: 0.4, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    // Start dots after logo entrance, staggered
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      for (var i = 0; i < 3; i++) {
        Future.delayed(Duration(milliseconds: i * 160), () {
          if (!mounted) return;
          _dotCtrls[i].repeat(reverse: true);
        });
      }
    });

    if (widget.onFinished != null) {
      _timer = Timer(const Duration(milliseconds: 1800), widget.onFinished!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoCtrl.dispose();
    for (final c in _dotCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo — circular with entrance animation
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: BreathingPulse(
                    duration: const Duration(milliseconds: 1600),
                    maxScale: 1.03,
                    child: Container(
                      width: 170,
                      height: 170,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: 0.18),
                            blurRadius: 48,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/logo_full.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // Staggered bouncing dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedBuilder(
                      animation: _dotScales[i],
                      builder: (_, __) => Transform.scale(
                        scale: _dotScales[i].value,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.orange
                                .withValues(alpha: 0.4 + _dotScales[i].value * 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
