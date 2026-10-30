import 'package:flutter/material.dart';

/// Official administrator marker. Visibility is derived only from the trusted
/// role returned in the authenticated account or community API payload.
class VerifiedAdminBadge extends StatelessWidget {
  final String role;
  final double size;

  const VerifiedAdminBadge({
    super.key,
    required this.role,
    this.size = 17,
  });

  @override
  Widget build(BuildContext context) {
    if (role != 'admin') return const SizedBox.shrink();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final label = isArabic
        ? 'حساب مسؤول رسمي موثّق من COVEY'
        : 'Verified official COVEY administrator';
    return Semantics(
      label: label,
      image: true,
      child: Tooltip(
        message: label,
        child: Icon(
          Icons.verified_rounded,
          key: const ValueKey('verified-admin-badge'),
          size: size,
          color: const Color(0xFF1D9BF0),
        ),
      ),
    );
  }
}
