import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/password_policy.dart';

class PasswordStrengthCard extends StatelessWidget {
  final String password;
  final bool requiredStrength;
  const PasswordStrengthCard(
      {super.key, required this.password, this.requiredStrength = true});
  @override
  Widget build(BuildContext context) {
    final strong = PasswordPolicy.validate(password) == null;
    final score = password.isEmpty
        ? 0
        : strong
            ? (password.length >= 12 && PasswordPolicy.kinds(password) == 4
                ? 4
                : 3)
            : (password.length >= 8 &&
                    PasswordPolicy.kinds(password) >= 2 &&
                    !PasswordPolicy.isCommon(password)
                ? 2
                : 1);
    final color = switch (score) {
      0 => AppColors.textSecondary,
      1 => AppColors.danger,
      2 => AppColors.orange,
      _ => const Color(0xFF18876A)
    };
    final label = switch (score) {
      0 => 'ابدأ الكتابة',
      1 => 'ضعيفة',
      2 => 'متوسطة',
      3 => 'قوية',
      _ => 'قوية جدًا'
    };
    final checks = [
      ('8 أحرف أو أكثر', password.length >= 8),
      ('أحرف كبيرة', PasswordPolicy.upper.hasMatch(password)),
      ('أحرف صغيرة أو عربية', PasswordPolicy.lower.hasMatch(password)),
      ('أرقام', PasswordPolicy.number.hasMatch(password)),
      ('رموز', PasswordPolicy.symbol.hasMatch(password)),
    ];
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shield_outlined,
                      color: AppColors.navy, size: 22)),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('قوة كلمة المرور',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.navy))),
              Flexible(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(label,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)))),
            ]),
            const SizedBox(height: 16),
            Row(
                children: List.generate(
                    4,
                    (index) => Expanded(
                            child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          height: 6,
                          margin: EdgeInsetsDirectional.only(
                              end: index == 3 ? 0 : 5),
                          decoration: BoxDecoration(
                              color: index < score
                                  ? color
                                  : const Color(0xFFE9EDF4),
                              borderRadius: BorderRadius.circular(6)),
                        )))),
            const SizedBox(height: 14),
            Text(
                requiredStrength
                    ? 'مطلوب: 8 أحرف و3 أنواع على الأقل، مع تجنب الكلمات الشائعة.'
                    : 'فحص إرشادي. استخدم كلمة مرور طويلة وغير شائعة لحماية حسابك.',
                style: AppTextStyles.caption.copyWith(height: 1.6)),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: checks
                    .map((check) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                              color: check.$2
                                  ? const Color(0xFFF0F8F5)
                                  : const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                check.$2
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: check.$2
                                    ? const Color(0xFF18876A)
                                    : AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Flexible(
                                child: Text(check.$1,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: check.$2
                                            ? const Color(0xFF18876A)
                                            : AppColors.textSecondary))),
                          ]),
                        ))
                    .toList()),
            if (password.isNotEmpty &&
                (PasswordPolicy.isCommon(password) ||
                    password.runes.toSet().length < 4)) ...[
              const SizedBox(height: 10),
              const Text('تجنب الكلمات الشائعة وتكرار نفس الأحرف.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ]),
        ));
  }
}
