import 'account_recovery_screen.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

class OTPVerificationScreen extends StatelessWidget {
  final String destination;
  final VoidCallback? onVerify;
  final VoidCallback? onResend;

  const OTPVerificationScreen({
    super.key,
    this.destination = '+90 5XX XXX XX 12',
    this.onVerify,
    this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'رمز التحقق',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحقق من رقمك', style: AppTextStyles.screenTitle),
            const SizedBox(height: 8),
            Text('أرسلنا رمز مكوّن من 6 أرقام إلى $destination',
                style: AppTextStyles.caption),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                6,
                (i) => Container(
                  width: 44,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == 0 ? AppColors.orange : AppColors.border,
                      width: i == 0 ? 1.6 : 1,
                    ),
                  ),
                  child: const Text('', style: AppTextStyles.screenTitle),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'تأكيد', onPressed: onVerify),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: onResend,
                child: RichText(
                  text: const TextSpan(
                    style: AppTextStyles.body,
                    children: [
                      TextSpan(text: 'لم يصلك الرمز؟ '),
                      TextSpan(
                        text: 'إعادة الإرسال',
                        style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordReset2FAScreen extends StatelessWidget {
  const PasswordReset2FAScreen({super.key});
  @override
  Widget build(BuildContext context) => const AccountRecoveryScreen();
}
