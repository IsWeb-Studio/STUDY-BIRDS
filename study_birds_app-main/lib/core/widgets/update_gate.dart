import '../../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../services/app_update_service.dart';

/// Shows [child] normally, or a full-screen "update required" page when the
/// server says this installed version is no longer supported.
class UpdateGate extends StatelessWidget {
  final AppUpdateService service;
  final Widget child;
  const UpdateGate({super.key, required this.service, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final required = service.required;
        if (required == null) return child;
        return Directionality(
          textDirection: appTextDirection,
          child: Material(
            color: AppColors.background,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                              color: AppColors.orangeSoft, shape: BoxShape.circle),
                          child: const Icon(Icons.system_update_rounded,
                              size: 40, color: AppColors.orange),
                        ),
                        const SizedBox(height: 22),
                        Text(context.l10n.updateTitle,
                            style: AppTextStyles.cardTitle,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text(
                            required.message == AppUpdateService.defaultMessage
                                ? context.l10n.updateDefaultMessage
                                : required.message,
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 14, height: 1.8),
                            textAlign: TextAlign.center),
                        if (required.storeUrl != null) ...[
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: context.l10n.updateNow,
                            icon: Icons.open_in_new_rounded,
                            onPressed: () => launchUrl(
                                Uri.parse(required.storeUrl!),
                                mode: LaunchMode.externalApplication),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
