import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/animations.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceFade;

  @override
  void initState() {
    super.initState();
    // Entrance: scale + fade in (0 -> 700ms), then the logo hands off to a
    // gentle breathing pulse (BreathingPulse wrapper below) for as long as
    // the splash stays on screen.
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entranceScale = Tween<double>(begin: 0.82, end: 1.0).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack));
    _entranceFade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _entranceController.forward();

    if (widget.onFinished != null) {
      _timer = Timer(const Duration(milliseconds: 1600), widget.onFinished!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entranceController.dispose();
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
              FadeTransition(
                opacity: _entranceFade,
                child: ScaleTransition(
                  scale: _entranceScale,
                  child: BreathingPulse(
                    duration: const Duration(milliseconds: 1400),
                    maxScale: 1.035,
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Image.asset('assets/images/logo_full.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: _entranceFade,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(AppColors.orange),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
