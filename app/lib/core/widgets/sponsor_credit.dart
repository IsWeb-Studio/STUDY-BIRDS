import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class SponsorCredit extends StatelessWidget {
  final double fontSize;
  final TextScaler? textScaler;
  const SponsorCredit({super.key, this.fontSize = 12, this.textScaler});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Sponsored by Study Birds',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  textScaler: textScaler,
                  style: TextStyle(
                      fontSize: fontSize,
                      height: 1.35,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            )),
        const Expanded(child: Divider(color: AppColors.border)),
      ]);
}
