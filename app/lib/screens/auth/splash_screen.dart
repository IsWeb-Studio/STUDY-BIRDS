import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/sponsor_credit.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.onFinished != null) {
      _timer = Timer(const Duration(milliseconds: 1800), widget.onFinished!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, constraints) {
              final width =
                  math.min(constraints.maxWidth, constraints.maxHeight / 1.76);
              return Center(
                  child: SizedBox(
                      width: width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Keep all twelve supplied panels; replace only the baked-in footer.
                          SizedBox(
                              width: width,
                              height: width * 1216 / 1024,
                              child: ClipRect(
                                  child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minWidth: width,
                                maxWidth: width,
                                minHeight: width * 1.5,
                                maxHeight: width * 1.5,
                                child: Image.asset(
                                    'assets/images/branding/covey_splash.png',
                                    width: width,
                                    height: width * 1.5,
                                    fit: BoxFit.contain,
                                    excludeFromSemantics: true),
                              ))),
                          SizedBox(height: width * .025),
                          Image.asset(
                              'assets/images/branding/covey_splash_mark.png',
                              key: const ValueKey('splash-covey-mark'),
                              width: width * .32,
                              height: width * .32,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true),
                          SizedBox(height: width * .015),
                          Text('COVEY',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                  fontSize: width * .075,
                                  height: 1.2,
                                  letterSpacing: width * .012,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF041E4A))),
                          SizedBox(height: width * .02),
                          SponsorCredit(
                              fontSize: width * .035,
                              textScaler: TextScaler.noScaling),
                        ],
                      )));
            }),
          ),
        ),
      );
}
