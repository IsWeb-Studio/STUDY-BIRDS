import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/password_policy.dart';

/// Quiet feedback for login, without a panel or a checklist.
class PasswordStrengthInline extends StatelessWidget {
  final String password;
  const PasswordStrengthInline({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final strong = PasswordPolicy.validate(password) == null;
    final score = strong
        ? 3
        : password.length >= 8 &&
                PasswordPolicy.kinds(password) >= 2 &&
                !PasswordPolicy.isCommon(password)
            ? 2
            : 1;
    final color = switch (score) {
      1 => AppColors.danger,
      2 => AppColors.orange,
      _ => const Color(0xFF18876A),
    };
    final label = switch (score) { 1 => 'ضعيفة', 2 => 'متوسطة', _ => 'قوية' };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(children: [
            Flexible(
                flex: 2,
                child: Text(label,
                    semanticsLabel: 'قوة كلمة المرور: $label',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))),
            const SizedBox(width: 14),
            Expanded(
                flex: 3,
                child: Row(
                    children: List.generate(
                        3,
                        (index) => Expanded(
                                child: AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              height: 3,
                              margin: EdgeInsetsDirectional.only(
                                  end: index == 2 ? 0 : 4),
                              decoration: BoxDecoration(
                                  color: index < score
                                      ? color
                                      : const Color(0xFFE9EDF4),
                                  borderRadius: BorderRadius.circular(3)),
                            ))))),
          ])),
    );
  }
}
