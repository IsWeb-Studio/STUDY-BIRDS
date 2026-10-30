import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A failed platform launch must give the user a visible result.
Future<bool> openExternalLink(BuildContext context, String value) async {
  try {
    final uri = Uri.tryParse(value.trim());
    if (uri != null &&
        const ['https', 'http', 'mailto', 'tel'].contains(uri.scheme) &&
        (!['https', 'http'].contains(uri.scheme) ||
            (uri.host.isNotEmpty && uri.userInfo.isEmpty)) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {
    // Includes platform failures and a device with no handler for the link.
  }
  if (!context.mounted) return false;
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final message = ar
      ? 'تعذر فتح الرابط. تحقق من الاتصال ومن وجود تطبيق مناسب، وحاول مجددًا.'
      : 'Could not open the link. Check your connection and available apps, then try again.';
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null && Scaffold.maybeOf(context) != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } else {
    await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(content: Text(message), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: Text(ar ? 'حسنًا' : 'OK'))
            ]));
  }
  return false;
}
