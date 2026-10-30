import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public resources stay available before authentication and after deletion.
class PrivacyLinks extends StatelessWidget {
  const PrivacyLinks({super.key});

  Future<void> _open(BuildContext context, String path) async {
    try {
      if (await launchUrl(Uri.https('studybirds.net', path),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // A missing browser must not break authentication or account settings.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('https://studybirds.net$path'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Wrap(alignment: WrapAlignment.center, children: [
      TextButton(
        onPressed: () => _open(context, '/privacy-policy'),
        child: Text(ar ? 'سياسة الخصوصية' : 'Privacy policy'),
      ),
      TextButton(
        onPressed: () => _open(context, '/contact'),
        child: Text(ar ? 'تواصل معنا' : 'Contact us'),
      ),
    ]);
  }
}
